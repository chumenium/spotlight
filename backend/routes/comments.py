"""
コメント管理API
コメントの投稿、取得、削除機能を提供
"""
from inspect import getcomments
from flask import Blueprint, request, jsonify
from database import Comment, Content, Notification
from datetime import datetime

comments_bp = Blueprint('comments', __name__, url_prefix='/api')

#未実装
@comments_bp.route('/comments', methods=['POST'])
def create_comment():
    """
    コンテンツにコメントを投稿
    
    Path Parameters:
    - content_id: コンテンツID
    
    Request Body:
    {
        "userID": "string (required)",
        "commenttext": "string (required)",
        "parentcommentID": "number (optional)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "commentID": "number",
            "userID": "string",
            "commenttext": "string",
            "parentcommentID": "number",
            "commenttimestamp": "string"
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
        if 'userID' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'userID is required'
                }
            }), 400
        
        if 'commenttext' not in data:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'MISSING_FIELD',
                    'message': 'commenttext is required'
                }
            }), 400
        
        # コメントテキストの長さチェック
        if len(data['commenttext'].strip()) == 0:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'INVALID_FIELD',
                    'message': 'commenttext cannot be empty'
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
        
        # 親コメントの存在確認（指定されている場合）
        parent_comment_id = data.get('parentcommentID')
        if parent_comment_id:
            parent_comments = Comment.get_replies(parent_comment_id)
            if not parent_comments:
                return jsonify({
                    'success': False,
                    'error': {
                        'code': 'PARENT_COMMENT_NOT_FOUND',
                        'message': 'Parent comment not found'
                    }
                }), 404
        
        # コメントを作成
        comment = Comment.create(
            content_id=content_id,
            user_id=data['userID'],
            comment_text=data['commenttext'],
            parent_comment_id=parent_comment_id
        )
        
        # 通知を作成（コンテンツの投稿者に通知）
        if content['userid'] != data['userID']:  # 自分のコンテンツには通知しない
            try:
                Notification.create(
                    user_id=content['userid'],
                    content_user_cid=content_id,
                    content_user_uid=data['userID'],
                    com_ct_id=content_id,
                    com_cm_id=comment['commentid']
                )
            except Exception:
                # 通知の作成に失敗してもコメント作成は成功とする
                pass
        
        return jsonify({
            'success': True,
            'data': comment
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to create comment: {str(e)}'
            }
        }), 500



@comments_bp.route('/comments', methods=['GET'])
def get_comments():
    """
    コンテンツのコメント一覧を取得
    
    Path Parameters:
    - content_id: コンテンツID
    
    Query Parameters:
    - include_replies: 返信を含めるかどうか (default: true)
    
    Response:
    {
        "success": true,
        "data": [
            {
                "contentID": "number",
                "commentID": "number",
                "userID": "string",
                "commenttext": "string",
                "parentcommentID": "number",
                "commenttimestamp": "string",
                "username": "string",
                "iconimgpath": "string",
                "replies": [
                    {
                        "contentID": "number",
                        "commentID": "number",
                        "userID": "string",
                        "commenttext": "string",
                        "parentcommentID": "number",
                        "commenttimestamp": "string",
                        "username": "string",
                        "iconimgpath": "string"
                    }
                ]
            }
        ]
    }
    """
    try:
        data = request.get_json()
        content_id = data.get("contentID")
        comment = Comment.get_by_content_id(content_id)
        print(comment)
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get comments: {str(e)}'
            }
        }), 500

@comments_bp.route('/<int:content_id>/comments/<int:comment_id>', methods=['GET'])
def get_comment(content_id, comment_id):
    """
    特定のコメントを取得
    
    Path Parameters:
    - content_id: コンテンツID
    - comment_id: コメントID
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "commentID": "number",
            "userID": "string",
            "commenttext": "string",
            "parentcommentID": "number",
            "commenttimestamp": "string",
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
                    FROM comment c
                    JOIN "user" u ON c.userID = u.userID
                    WHERE c.contentID = %s AND c.commentID = %s
                """, (content_id, comment_id))
                
                comment = cursor.fetchone()
        
        if not comment:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'COMMENT_NOT_FOUND',
                    'message': 'Comment not found'
                }
            }), 404
        
        return jsonify({
            'success': True,
            'data': dict(comment)
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get comment: {str(e)}'
            }
        }), 500

@comments_bp.route('/<int:content_id>/comments/<int:comment_id>/replies', methods=['GET'])
def get_comment_replies(content_id, comment_id):
    """
    コメントの返信一覧を取得
    
    Path Parameters:
    - content_id: コンテンツID
    - comment_id: コメントID
    
    Response:
    {
        "success": true,
        "data": [
            {
                "contentID": "number",
                "commentID": "number",
                "userID": "string",
                "commenttext": "string",
                "parentcommentID": "number",
                "commenttimestamp": "string",
                "username": "string",
                "iconimgpath": "string"
            }
        ]
    }
    """
    try:
        # 親コメントの存在確認
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM comment 
                    WHERE contentID = %s AND commentID = %s
                """, (content_id, comment_id))
                
                parent_comment = cursor.fetchone()
        
        if not parent_comment:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'COMMENT_NOT_FOUND',
                    'message': 'Parent comment not found'
                }
            }), 404
        
        # 返信コメントを取得
        replies = Comment.get_replies(comment_id)
        
        return jsonify({
            'success': True,
            'data': [dict(reply) for reply in replies]
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get comment replies: {str(e)}'
            }
        }), 500

@comments_bp.route('/<int:content_id>/comments/<int:comment_id>', methods=['DELETE'])
def delete_comment(content_id, comment_id):
    """
    コメントを削除
    
    Path Parameters:
    - content_id: コンテンツID
    - comment_id: コメントID
    
    Request Body:
    {
        "userID": "string (required)"
    }
    
    Response:
    {
        "success": true,
        "data": {
            "message": "Comment deleted successfully"
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
        
        # コメントの存在確認と所有者確認
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    SELECT * FROM comment 
                    WHERE contentID = %s AND commentID = %s
                """, (content_id, comment_id))
                
                comment = cursor.fetchone()
        
        if not comment:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'COMMENT_NOT_FOUND',
                    'message': 'Comment not found'
                }
            }), 404
        
        # 所有者確認
        if comment['userid'] != data['userID']:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'PERMISSION_DENIED',
                    'message': 'You can only delete your own comments'
                }
            }), 403
        
        # コメントを削除
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute("""
                    DELETE FROM comment 
                    WHERE contentID = %s AND commentID = %s
                """, (content_id, comment_id))
                conn.commit()
        
        return jsonify({
            'success': True,
            'data': {
                'message': 'Comment deleted successfully'
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to delete comment: {str(e)}'
            }
        }), 500

@comments_bp.route('/<int:content_id>/comments/count', methods=['GET'])
def get_comment_count(content_id):
    """
    コンテンツのコメント数を取得
    
    Path Parameters:
    - content_id: コンテンツID
    
    Response:
    {
        "success": true,
        "data": {
            "contentID": "number",
            "totalComments": "number",
            "totalReplies": "number"
        }
    }
    """
    try:
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
        
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                # 総コメント数（返信含む）
                cursor.execute("""
                    SELECT COUNT(*) FROM comment 
                    WHERE contentID = %s
                """, (content_id,))
                total_comments = cursor.fetchone()['count']
                
                # 返信コメント数
                cursor.execute("""
                    SELECT COUNT(*) FROM comment 
                    WHERE contentID = %s AND parentcommentID IS NOT NULL
                """, (content_id,))
                total_replies = cursor.fetchone()['count']
        
        return jsonify({
            'success': True,
            'data': {
                'contentID': content_id,
                'totalComments': total_comments,
                'totalReplies': total_replies
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': f'Failed to get comment count: {str(e)}'
            }
        }), 500

get_comments()