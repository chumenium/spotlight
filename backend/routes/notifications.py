"""
通知管理API
通知の取得、管理機能を提供
"""
from flask import Blueprint, request, jsonify
from database import Notification, User
from datetime import datetime

notifications_bp = Blueprint('notifications', __name__, url_prefix='/api/notifications')

@notifications_bp.route('/', methods=['GET'])
def get_notifications():
    """
    ユーザーの通知一覧を取得
    
    Query Parameters:
    - userID: ユーザーID (required)
    - limit: 取得件数 (default: 20, max: 100)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "userID": "string",
                "notificationID": "number",
                "notificationtimestamp": "string",
                "contentuserCID": "number",
                "contentuserUID": "string",
                "comCTID": "number",
                "comCMID": "number",
                "title": "string",
                "contentpath": "string",
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
        
        # 通知一覧を取得
        notifications = Notification.get_user_notifications(user_id, limit)
        
        return jsonify({
            'success': True,
            'data': notifications
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get notifications: {str(e)}'
            }
        }), 500

@notifications_bp.route('/count', methods=['GET'])
def get_notification_count():
    """
    ユーザーの未読通知数を取得
    
    Query Parameters:
    - userID: ユーザーID (required)
    
    Response:
    {
        "success": true,
        "data": {
            "userID": "string",
            "unreadCount": "number"
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
        
        # 通知数を取得
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT COUNT(*) FROM notification WHERE userID = %s
                """, (user_id,))
                count = cursor.fetchone()['count']
        
        return jsonify({
            'success': True,
            'data': {
                'userID': user_id,
                'unreadCount': count
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get notification count: {str(e)}'
            }
        }), 500

@notifications_bp.route('/<int:notification_id>', methods=['DELETE'])
def delete_notification(notification_id):
    """
    通知を削除
    
    Path Parameters:
    - notification_id: 通知ID
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Notification deleted successfully"
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
        
        # 通知を削除
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM notification 
                    WHERE userID = %s AND notificationID = %s
                """, (data['userID'], notification_id))
                conn.commit()
        
        if cursor.rowcount == 0:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'NOTIFICATION_NOT_FOUND',
                    'message': 'Notification not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Notification deleted successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to delete notification: {str(e)}'
            }
        }), 500

@notifications_bp.route('/clear', methods=['DELETE'])
def clear_all_notifications():
    """
    ユーザーのすべての通知をクリア
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "All notifications cleared successfully"
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
        
        # すべての通知をクリア
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM notification WHERE userID = %s
                """, (data['userID'],))
                conn.commit()
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'All notifications cleared successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to clear notifications: {str(e)}'
            }
        }), 500