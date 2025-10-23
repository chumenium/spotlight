"""
再生履歴管理API
再生履歴の取得、管理機能を提供
"""
from flask import Blueprint, request, jsonify
from database import PlayHistory, User, Content
from datetime import datetime

playhistory_bp = Blueprint('playhistory', __name__, url_prefix='/api/playhistory')

@playhistory_bp.route('/', methods=['GET'])
def get_play_history():
    """
    ユーザーの再生履歴を取得
    
    Query Parameters:
    - userID: ユーザーID (required)
    - limit: 取得件数 (default: 20, max: 100)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "userID": "string",
                "playID": "number",
                "contentID": "number",
                "title": "string",
                "contentpath": "string",
                "link": "string",
                "username": "string",
                "iconimgpath": "string"
            }
        ]
    }
    """
    try:
        user_id = request.args.get('userID')
        limit = min(int(request.args.get('limit', 20)), 100)
        
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
        
        # 再生履歴を取得
        history = PlayHistory.get_user_play_history(user_id, limit)
        
        return jsonify({
            'success': True,
            'data': history
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get play history: {str(e)}'
            }
        }), 500

@playhistory_bp.route('/', methods=['POST'])
def add_play_history():
    """
    再生履歴を追加
    
    Request Body:
    {
        "userID": "string (required)",
        "contentID": "number (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "playID": "number",
            "contentID": "number"
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
        
        if 'contentID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'contentID is required'
                }
            }), 400
        
        # ユーザーの存在確認
        user = User.get_by_id(data['userID'])
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # コンテンツの存在確認
        content = Content.get_by_id(data['contentID'])
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'CONTENT_NOT_FOUND',
                    'message': 'Content not found'
                }
            }), 404
        
        # 再生履歴を追加
        history = PlayHistory.add_play(data['userID'], data['contentID'])
        
        return jsonify({
            'success': True,
            'data': history
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to add play history: {str(e)}'
            }
        }), 500

@playhistory_bp.route('/clear', methods=['DELETE'])
def clear_play_history():
    """
    ユーザーの再生履歴をクリア
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Play history cleared successfully"
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
        
        # ユーザーの存在確認
        user = User.get_by_id(data['userID'])
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # 再生履歴をクリア
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM playhistory WHERE userID = %s
                """, (data['userID'],))
                conn.commit()
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Play history cleared successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to clear play history: {str(e)}'
            }
        }), 500

@playhistory_bp.route('/stats', methods=['GET'])
def get_play_stats():
    """
    ユーザーの再生統計を取得
    
    Query Parameters:
    - userID: ユーザーID (required)
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "totalPlays": "number",
            "uniqueContent": "number",
            "mostPlayedContent": {
                "contentID": "number",
                "title": "string",
                "playCount": "number"
            }
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
        
        # 再生統計を取得
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 総再生回数
                cursor.execute("""
                    SELECT COUNT(*) FROM playhistory WHERE userID = %s
                """, (user_id,))
                total_plays = cursor.fetchone()['count']
                
                # 再生したユニークなコンテンツ数
                cursor.execute("""
                    SELECT COUNT(DISTINCT contentID) FROM playhistory WHERE userID = %s
                """, (user_id,))
                unique_content = cursor.fetchone()['count']
                
                # 最も再生されたコンテンツ
                cursor.execute("""
                    SELECT ph.contentID, c.title, COUNT(*) as playCount
                    FROM playhistory ph
                    JOIN content c ON ph.contentID = c.contentID
                    WHERE ph.userID = %s
                    GROUP BY ph.contentID, c.title
                    ORDER BY playCount DESC
                    LIMIT 1
                """, (user_id,))
                
                most_played = cursor.fetchone()
                most_played_content = None
                if most_played:
                    most_played_content = {
                        'contentID': most_played['contentid'],
                        'title': most_played['title'],
                        'playCount': most_played['playcount']
                    }
        
        stats = {
            'userID': user_id,
            'totalPlays': total_plays,
            'uniqueContent': unique_content,
            'mostPlayedContent': most_played_content
        }
        
        return jsonify({
            'success': True,
            'data': stats
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get play stats: {str(e)}'
            }
        }), 500
