"""
検索機能API
コンテンツの検索と検索履歴管理機能を提供
"""
from flask import Blueprint, request, jsonify
from database import SearchHistory, Content, User
from datetime import datetime

search_bp = Blueprint('search', __name__, url_prefix='/api/search')

@search_bp.route('/', methods=['GET'])
def search_content():
    """
    コンテンツを検索
    
    Query Parameters:
    - q: 検索キーワード (required)
    - userID: ユーザーID (optional, 検索履歴に保存する場合)
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
        query = request.args.get('q')
        user_id = request.args.get('userID')
        limit = min(int(request.args.get('limit', 20)), 100)
        offset = int(request.args.get('offset', 0))
        sort = request.args.get('sort', 'newest')
        
        if not query:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'q parameter is required'
                }
            }), 400
        
        # 検索履歴に保存（ユーザーIDが提供されている場合）
        if user_id:
            try:
                SearchHistory.add_search(user_id, query)
            except Exception:
                # 検索履歴の保存に失敗しても検索は続行
                pass
        
        # ソート順の設定
        sort_options = {
            'newest': 'c.posttimestamp DESC',
            'oldest': 'c.posttimestamp ASC',
            'popular': 'c.playnum DESC, c.posttimestamp DESC'
        }
        order_by = sort_options.get(sort, 'c.posttimestamp DESC')
        
        # 検索実行
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 総件数を取得
                cursor.execute("""
                    SELECT COUNT(*) FROM content c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.title ILIKE %s OR c.contentpath ILIKE %s
                """, (f'%{query}%', f'%{query}%'))
                total = cursor.fetchone()['count']
                
                # 検索結果を取得
                cursor.execute(f"""
                    SELECT c.*, u.username, u.iconimgpath
                    FROM content c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.title ILIKE %s OR c.contentpath ILIKE %s
                    ORDER BY {order_by}
                    LIMIT %s OFFSET %s
                """, (f'%{query}%', f'%{query}%', limit, offset))
                
                results = [dict(row) for row in cursor.fetchall()]
        
        return jsonify({
            'success': True,
            'data': results,
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
                'message': f'Failed to search content: {str(e)}'
            }
        }), 500

@search_bp.route('/history', methods=['GET'])
def get_search_history():
    """
    ユーザーの検索履歴を取得
    
    Query Parameters:
    - userID: ユーザーID (required)
    - limit: 取得件数 (default: 10, max: 50)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "userID": "string",
                "serchID": "number",
                "serchword": "string"
            }
        ]
    }
    """
    try:
        user_id = request.args.get('userID')
        limit = min(int(request.args.get('limit', 10)), 50)
        
        if not user_id:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_PARAMETER',
                    'message': 'userID parameter is required'
                }
            }), 400
        
        # ユーザーの存在確認
        user = User.get_by_id(user_id)
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # 検索履歴を取得
        history = SearchHistory.get_user_search_history(user_id, limit)
        
        return jsonify({
            'success': True,
            'data': history
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get search history: {str(e)}'
            }
        }), 500

@search_bp.route('/history', methods=['DELETE'])
def clear_search_history():
    """
    ユーザーの検索履歴をクリア
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Search history cleared successfully"
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
        
        # 検索履歴をクリア
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM serchhistory WHERE userID = %s
                """, (data['userID'],))
                conn.commit()
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Search history cleared successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to clear search history: {str(e)}'
            }
        }), 500

@search_bp.route('/suggestions', methods=['GET'])
def get_search_suggestions():
    """
    検索候補を取得（人気の検索キーワード）
    
    Query Parameters:
    - limit: 取得件数 (default: 10, max: 20)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "serchword": "string",
                "count": "number"
            }
        ]
    }
    """
    try:
        limit = min(int(request.args.get('limit', 10)), 20)
        
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT serchword, COUNT(*) as count
                    FROM serchhistory
                    GROUP BY serchword
                    ORDER BY count DESC, serchword ASC
                    LIMIT %s
                """, (limit,))
                
                suggestions = [dict(row) for row in cursor.fetchall()]
        
        return jsonify({
            'success': True,
            'data': suggestions
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get search suggestions: {str(e)}'
            }
        }), 500