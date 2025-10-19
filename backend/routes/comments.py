"""
コメント関連のエンドポイント
コメントの取得、作成など
"""
from flask import Blueprint, request, jsonify
from utils.auth import jwt_required

comments_bp = Blueprint('comments', __name__)

@comments_bp.route('/api/posts/<post_id>/comments', methods=['GET'])
def get_comments(post_id):
    """
    コメント一覧取得
    
    Args:
        post_id (str): 投稿ID
    
    Query Parameters:
        page (int): ページ番号
        limit (int): 取得件数
    
    Returns:
        JSON: コメント一覧とページネーション情報
    """
    try:
        page = request.args.get('page', 1, type=int)
        limit = request.args.get('limit', 20, type=int)
        
        # TODO: DB担当メンバーがコメント取得処理を実装
        
        # モックデータ
        mock_comments = [
            {
                'id': f'comment_{i}',
                'postId': post_id,
                'userId': f'user_{i}',
                'username': f'コメント者{i}',
                'userAvatar': f'https://example.com/avatar{i}.jpg',
                'content': f'コメント内容{i}',
                'likes': i * 2,
                'createdAt': '2024-01-01T00:00:00Z'
            }
            for i in range(1, min(limit, 5) + 1)
        ]
        
        return jsonify({
            'success': True,
            'data': {
                'comments': mock_comments,
                'pagination': {
                    'currentPage': page,
                    'totalPages': 5,
                    'totalItems': 100,
                    'hasNext': page < 5,
                    'hasPrev': page > 1
                }
            }
        }), 200
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

@comments_bp.route('/api/posts/<post_id>/comments', methods=['POST'])
@jwt_required
def create_comment(post_id):
    """
    コメント作成（認証必須）
    
    Args:
        post_id (str): 投稿ID
    
    Request Body:
        {
            "content": "コメント内容"
        }
    
    Returns:
        JSON: 作成されたコメント情報
    """
    try:
        data = request.get_json()
        user = request.user
        content = data.get('content')
        
        # バリデーション
        if not content:
            return jsonify({
                'success': False,
                'error': {
                    'code': 'VALIDATION_ERROR',
                    'message': 'Content is required'
                }
            }), 400
        
        # TODO: DB担当メンバーがコメント作成処理を実装
        
        # モックレスポンス
        new_comment = {
            'id': 'comment_new_123',
            'postId': post_id,
            'userId': user.get('user_id', 'user_123'),
            'username': user.get('nickname', 'テストユーザー'),
            'userAvatar': 'https://example.com/avatar.jpg',
            'content': content,
            'likes': 0,
            'createdAt': '2024-01-01T00:00:00Z'
        }
        
        return jsonify({
            'success': True,
            'data': {
                'comment': new_comment
            }
        }), 201
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': str(e)
            }
        }), 500

