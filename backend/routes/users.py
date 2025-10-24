"""
ユーザー管理API
ユーザーの登録、取得、更新、削除機能を提供
"""
from flask import Blueprint, request, jsonify
from database import User
import uuid
from datetime import datetime

users_bp = Blueprint('users', __name__, url_prefix='/api/users')

@users_bp.route('/', methods=['POST'])
def create_user():
    """
    新しいユーザーを作成
    
    Request Body:
    {
        "userID": "string (optional, auto-generated if not provided)",
        "username": "string (required)",
        "iconimgpath": "string (optional)",
        "token": "string (optional)",
        "notificationenabled": "boolean (optional, default: false)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "username": "string",
            "iconimgpath": "string",
            "token": "string",
            "notificationenabled": "boolean"
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
        if 'username' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'username is required'
                }
            }), 400
        
        # ユーザーIDが提供されていない場合は自動生成
        user_id = data.get('userID', str(uuid.uuid4()))
        username = data.get('username')
        icon_img_path = data.get('iconimgpath')
        token = data.get('token')
        notification_enabled = data.get('notificationenabled', False)
        
        # ユーザー名の長さチェック
        if len(username) > 30:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_FIELD',
                    'message': 'username must be 30 characters or less'
                }
            }), 400
        
        # ユーザーを作成
        user = User.create(
            user_id=user_id,
            username=username,
            icon_img_path=icon_img_path,
            token=token,
            notification_enabled=notification_enabled
        )
        
        return jsonify({
            'success': True,
            'data': user
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to create user: {str(e)}'
            }
        }), 500

@users_bp.route('/<user_id>', methods=['GET'])
def get_user(user_id):
    """
    ユーザー情報を取得
    
    Path Parameters:
    - user_id: ユーザーID
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "username": "string",
            "iconimgpath": "string",
            "token": "string",
            "notificationenabled": "boolean"
        }
    }
    """
    try:
        user = User.get_by_id(user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': user
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get user: {str(e)}'
            }
        }), 500

@users_bp.route('/<user_id>', methods=['PUT'])
def update_user(user_id):
    """
    ユーザー情報を更新
    
    Path Parameters:
    - user_id: ユーザーID
    
    Request Body:
    {
        "username": "string (optional)",
        "iconimgpath": "string (optional)",
        "token": "string (optional)",
        "notificationenabled": "boolean (optional)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "username": "string",
            "iconimgpath": "string",
            "token": "string",
            "notificationenabled": "boolean"
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
        
        # 更新可能なフィールドを抽出
        update_data = {}
        if 'username' in data:
            if len(data['username']) > 30:
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'INVALID_FIELD',
                        'message': 'username must be 30 characters or less'
                    }
                }), 400
            update_data['username'] = data['username']
        
        if 'iconimgpath' in data:
            update_data['icon_img_path'] = data['iconimgpath']
        
        if 'token' in data:
            update_data['token'] = data['token']
        
        if 'notificationenabled' in data:
            update_data['notification_enabled'] = data['notificationenabled']
        
        # ユーザーを更新
        user = User.update(user_id, **update_data)
        
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': user
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to update user: {str(e)}'
            }
        }), 500

@users_bp.route('/<user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    """
    ユーザープロフィール情報を取得（公開情報のみ）
    
    Path Parameters:
    - user_id: ユーザーID
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "username": "string",
            "iconimgpath": "string",
            "notificationenabled": "boolean"
        }
    }
    """
    try:
        user = User.get_by_id(user_id)
        
        if not user:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'USER_NOT_FOUND',
                    'message': 'User not found'
                }
            }), 404
        
        # 公開情報のみを返す（tokenは除外）
        profile_data = {
            'userID': user['userid'],
            'username': user['username'],
            'iconimgpath': user['iconimgpath'],
            'notificationenabled': user['notificationenabled']
        }
        
        return jsonify({
            'success': True,
            'data': profile_data
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get user profile: {str(e)}'
            }
        }), 500

@users_bp.route('/<user_id>/stats', methods=['GET'])
def get_user_stats(user_id):
    """
    ユーザーの統計情報を取得
    
    Path Parameters:
    - user_id: ユーザーID
    
    Response:
    {
        "success": true,
        "data": {
            "totalContent": "number",
            "totalSpotlights": "number",
            "totalBookmarks": "number",
            "totalComments": "number",
            "totalPlaylists": "number"
        }
    }
    """
    try:
        from database import Content, ContentUser, Comment, Playlist
        
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
        
        # 統計情報を計算
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 投稿したコンテンツ数
                cursor.execute("SELECT COUNT(*) FROM content WHERE userID = %s", (user_id,))
                total_content = cursor.fetchone()['count']
                
                # スポットライトした数
                cursor.execute("SELECT COUNT(*) FROM contentuser WHERE userID = %s AND spotlightflag = TRUE", (user_id,))
                total_spotlights = cursor.fetchone()['count']
                
                # ブックマークした数
                cursor.execute("SELECT COUNT(*) FROM contentuser WHERE userID = %s AND bookmarkflag = TRUE", (user_id,))
                total_bookmarks = cursor.fetchone()['count']
                
                # コメント数
                cursor.execute("SELECT COUNT(*) FROM comment WHERE userID = %s", (user_id,))
                total_comments = cursor.fetchone()['count']
                
                # プレイリスト数
                cursor.execute("SELECT COUNT(*) FROM playlist WHERE userID = %s", (user_id,))
                total_playlists = cursor.fetchone()['count']
        
        stats = {
            'totalContent': total_content,
            'totalSpotlights': total_spotlights,
            'totalBookmarks': total_bookmarks,
            'totalComments': total_comments,
            'totalPlaylists': total_playlists
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
                'message': f'Failed to get user stats: {str(e)}'
            }
        }), 500