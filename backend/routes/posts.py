"""
コンテンツ管理API
コンテンツの投稿、取得、更新、削除機能を提供
"""
from flask import Blueprint, request, jsonify
from database import Content, ContentUser, PlayHistory
from datetime import datetime
import os

posts_bp = Blueprint('posts', __name__, url_prefix='/api/posts')

@posts_bp.route('/', methods=['POST'])
def create_content():
    """
    新しいコンテンツを投稿
    
    Request Body:
    {
        "userID": "string (required)",
        "contentpath": "string (required)",
        "link": "string (required)",
        "title": "string (required)",
        "spotlightnum": "number (optional, default: 0)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "userID": "string",
            "contentpath": "string",
            "link": "string",
            "title": "string",
            "spotlightnum": "number",
            "posttimestamp": "string",
            "playnum": "number"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        # 必須フィールドのチェック
        required_fields = ['userID', 'contentpath', 'link', 'title']
        for field in required_fields:
            if field not in data:
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'MISSING_FIELD',
                        'message': f'{field} is required'
                    }
                }), 400
        
        # フィールド長のチェック
        if len(data['contentpath']) > 128:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_FIELD',
                    'message': 'contentpath must be 128 characters or less'
                }
            }), 400
        
        if len(data['link']) > 128:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_FIELD',
                    'message': 'link must be 128 characters or less'
                }
            }), 400
        
        if len(data['title']) > 128:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_FIELD',
                    'message': 'title must be 128 characters or less'
                }
            }), 400
        
        # コンテンツを作成
        content = Content.create(
            user_id=data['userID'],
            content_path=data['contentpath'],
            link=data['link'],
            title=data['title'],
            spotlight_num=data.get('spotlightnum', 0)
        )
        
        return jsonify({
            'success': True,
            'data': content
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to create content: {str(e)}'
            }
        }), 500

@posts_bp.route('/', methods=['GET'])
def get_all_content():
    """
    すべてのコンテンツを取得（ページネーション対応）
    
    Query Parameters:
    - limit: 取得件数 (default: 20, max: 100)
    - offset: オフセット (default: 0)
    - sort: ソート順 ('newest', 'oldest', 'popular') (default: 'newest')
    
    Response:
    {
        "success": true,
        "data": [
            {
                "contentID": "number",
                "userID": "string",
                "contentpath": "string",
                "link": "string",
                "title": "string",
                "spotlightnum": "number",
                "posttimestamp": "string",
                "playnum": "number",
                "username": "string",
                "iconimgpath": "string"
            }
        ],
        "pagination": {
            "limit": "number",
            "offset": "number",
            "total": "number"
        }
    }
    """
    try:
        # クエリパラメータの取得
        limit = min(int(request.args.get('limit', 20)), 100)  # 最大100件
        offset = int(request.args.get('offset', 0))
        sort = request.args.get('sort', 'newest')
        
        # ソート順の設定
        sort_options = {
            'newest': 'c.posttimestamp DESC',
            'oldest': 'c.posttimestamp ASC',
            'popular': 'c.playnum DESC, c.posttimestamp DESC'
        }
        order_by = sort_options.get(sort, 'c.posttimestamp DESC')
        
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 総件数を取得
                cursor.execute("SELECT COUNT(*) FROM content")
                total = cursor.fetchone()['count']
                
                # コンテンツ一覧を取得
                cursor.execute(f"""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM content c
                    JOIN "user" u ON c.userID = u.userID
                    ORDER BY {order_by}
                    LIMIT %s OFFSET %s
                """, (limit, offset))
                
                contents = [dict(row) for row in cursor.fetchall()]
        
        return jsonify({
            'success': True,
            'data': contents,
            'pagination': {
                'limit': limit,
                'offset': offset,
                'total': total
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get content: {str(e)}'
            }
        }), 500

@posts_bp.route('/<int:content_id>', methods=['GET'])
def get_content(content_id):
    """
    特定のコンテンツを取得
    
    Path Parameters:
    - content_id: コンテンツID
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "userID": "string",
            "contentpath": "string",
            "link": "string",
            "title": "string",
            "spotlightnum": "number",
            "posttimestamp": "string",
            "playnum": "number",
            "username": "string",
            "iconimgpath": "string"
        }
    }
    """
    try:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM content c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.contentID = %s
                """, (content_id,))
                
                content = cursor.fetchone()
        
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': dict(content)
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get content: {str(e)}'
            }
        }), 500

@posts_bp.route('/<int:content_id>/play', methods=['POST'])
def play_content(content_id):
    """
    コンテンツを再生（再生回数を増加）
    
    Path Parameters:
    - content_id: コンテンツID
    
    Request Body:
    {
        "userID": "string (optional)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "playnum": "number"
        }
    }
    """
    try:
        data = request.get_json() or {}
        user_id = data.get('userID')
        
        # コンテンツの存在確認
        content = Content.get_by_id(content_id)
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # 再生回数を増加
        success = Content.increment_play_count(content_id)
        if not success:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'UPDATE_FAILED',
                    'message': 'Failed to increment play count'
                }
            }), 500
        
        # 再生履歴に追加（ユーザーIDが提供されている場合）
        if user_id:
            try:
                PlayHistory.add_play(user_id, content_id)
            except Exception:
                # 再生履歴の追加に失敗しても再生回数の更新は成功とする
                pass
        
        # 更新されたコンテンツ情報を取得
        updated_content = Content.get_by_id(content_id)
        
        return jsonify({
            'success': True,
            'data': {
                'contentID': content_id,
                'playnum': updated_content['playnum']
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to play content: {str(e)}'
            }
        }), 500

@posts_bp.route('/<int:content_id>/spotlight', methods=['POST'])
def spotlight_content(content_id):
    """
    コンテンツにスポットライトを付与/削除
    
    Path Parameters:
    - content_id: コンテンツID
    
    Request Body:
    {
        "userID": "string (required)",
        "spotlight": "boolean (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "userID": "string",
            "spotlightflag": "boolean",
            "bookmarkflag": "boolean"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        if 'spotlight' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'spotlight is required'
                }
            }), 400
        
        # コンテンツの存在確認
        content = Content.get_by_id(content_id)
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # スポットライトフラグを設定
        result = ContentUser.set_spotlight(content_id, data['userID'], data['spotlight'])
        
        # スポットライト数を更新
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT COUNT(*) FROM contentuser 
                    WHERE contentID = %s AND spotlightflag = TRUE
                """, (content_id,))
                spotlight_count = cursor.fetchone()['count']
                
                Content.update_spotlight_count(content_id, spotlight_count)
        
        return jsonify({
            'success': True,
            'data': result
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to spotlight content: {str(e)}'
            }
        }), 500

@posts_bp.route('/<int:content_id>/bookmark', methods=['POST'])
def bookmark_content(content_id):
    """
    コンテンツをブックマーク/ブックマーク解除
    
    Path Parameters:
    - content_id: コンテンツID
    
    Request Body:
    {
        "userID": "string (required)",
        "bookmark": "boolean (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "userID": "string",
            "spotlightflag": "boolean",
            "bookmarkflag": "boolean"
        }
    }
    """
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_REQUEST',
                    'message': 'Request body is required'
                }
            }), 400
        
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        if 'bookmark' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'bookmark is required'
                }
            }), 400
        
        # コンテンツの存在確認
        content = Content.get_by_id(content_id)
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # ブックマークフラグを設定
        result = ContentUser.set_bookmark(content_id, data['userID'], data['bookmark'])
        
        return jsonify({
            'success': True,
            'data': result
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to bookmark content: {str(e)}'
            }
        }), 500

@posts_bp.route('/<int:content_id>/status', methods=['GET'])
def get_content_status(content_id):
    """
    ユーザーのコンテンツ状態を取得（スポットライト・ブックマーク）
    
    Path Parameters:
    - content_id: コンテンツID
    
    Query Parameters:
    - userID: ユーザーID (required)
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "userID": "string",
            "spotlightflag": "boolean",
            "bookmarkflag": "boolean"
        }
    }
    """
    try:
        user_id = request.args.get('userID')
        
        if not user_id:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'userID parameter is required'
                }
            }), 400
        
        # コンテンツの存在確認
        content = Content.get_by_id(content_id)
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # ユーザーのコンテンツ状態を取得
        status = ContentUser.get_user_content_status(content_id, user_id)
        
        if not status:
            # 状態が存在しない場合はデフォルト値を返す
            status = {
                'contentid': content_id,
                'userid': user_id,
                'spotlightflag': False,
                'bookmarkflag': False
            }
        
        return jsonify({
            'success': True,
            'data': status
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get content status: {str(e)}'
            }
        }), 500