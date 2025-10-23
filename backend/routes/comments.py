"""
コメント管理API
コメントの投稿、取得、削除機能を提供
"""
from inspect import getcomments
from flask import Blueprint, request, jsonify
from database import Comment, Content, Notification
from datetime import datetime

comments_bp = Blueprint('comments', __name__, url_prefix='/api')


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
        
