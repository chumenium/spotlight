"""
SpotLight バックエンド API
Flaskアプリケーションのメインファイル
"""
from flask import Flask, jsonify
from flask_cors import CORS
import os

# 設定のインポート
from config import config

# ルート（エンドポイント）のインポート
from routes.auth import auth_bp
from routes.posts import posts_bp
from routes.comments import comments_bp
from routes.search import search_bp
from routes.users import users_bp
from routes.notifications import notifications_bp
from routes.playlists import playlists_bp
from routes.playhistory import playhistory_bp

def create_app(config_name='default'):
    """
    Flaskアプリケーションのファクトリー関数
    
    Args:
        config_name (str): 設定名（development, production, default）
    
    Returns:
        Flask: Flaskアプリケーションインスタンス
    """
    # Flaskアプリケーションの初期化
    app = Flask(__name__)
    
    # 設定の読み込み
    app.config.from_object(config[config_name])
    
    # CORSの設定
    CORS(app, resources={
        r"/api/*": {
            "origins": app.config['CORS_ORIGINS'],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"]
        }
    })
    
    # Blueprintの登録
    app.register_blueprint(auth_bp)
    app.register_blueprint(posts_bp)
    app.register_blueprint(comments_bp)
    app.register_blueprint(search_bp)
    app.register_blueprint(users_bp)
    app.register_blueprint(notifications_bp)
    app.register_blueprint(playlists_bp)
    app.register_blueprint(playhistory_bp)
    
    # ヘルスチェックエンドポイント
    @app.route('/api/health', methods=['GET'])
    def health_check():
        """
        ヘルスチェック
        サーバーの稼働状況を確認
        """
        return jsonify({
            'success': True,
            'data': {
                'status': 'healthy',
                'message': 'SpotLight API is running'
            }
        }), 200
    
    # ルートエンドポイント
    @app.route('/', methods=['GET'])
    def root():
        """
        ルートエンドポイント
        APIの基本情報を返す
        """
        return jsonify({
            'success': True,
            'data': {
                'name': 'SpotLight API',
                'version': '1.0.0',
                'description': '隠れた才能発見プラットフォーム',
                'endpoints': {
                    'auth': '/api/auth',
                    'posts': '/api/posts',
                    'comments': '/api/posts/<post_id>/comments',
                    'search': '/api/search',
                    'users': '/api/users',
                    'notifications': '/api/notifications',
                    'playlists': '/api/playlists',
                    'playhistory': '/api/playhistory',
                    'health': '/api/health'
                }
            }
        }), 200
    
    # エラーハンドラー
    @app.errorhandler(404)
    def not_found(error):
        """404エラーハンドラー"""
        return jsonify({
            'success': False,
            'error': {
                'code': 'RESOURCE_NOT_FOUND',
                'message': 'The requested resource was not found'
            }
        }), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        """500エラーハンドラー"""
        return jsonify({
            'success': False,
            'error': {
                'code': 'SERVER_ERROR',
                'message': 'Internal server error occurred'
            }
        }), 500
    
    @app.errorhandler(401)
    def unauthorized(error):
        """401エラーハンドラー"""
        return jsonify({
            'success': False,
            'error': {
                'code': 'AUTHENTICATION_ERROR',
                'message': 'Authentication required'
            }
        }), 401
    
    @app.errorhandler(403)
    def forbidden(error):
        """403エラーハンドラー"""
        return jsonify({
            'success': False,
            'error': {
                'code': 'AUTHORIZATION_ERROR',
                'message': 'You do not have permission to access this resource'
            }
        }), 403
    
    return app

# アプリケーションインスタンスの作成
app = create_app(os.getenv('FLASK_ENV', 'development'))

if __name__ == '__main__':
    # 開発サーバーの起動
    print("=" * 60)
    print("SpotLight API Server Starting...")
    print("=" * 60)
    print(f"Environment: {os.getenv('FLASK_ENV', 'development')}")
    print(f"Host: {app.config['HOST']}")
    print(f"Port: {app.config['PORT']}")
    print(f"Debug: {app.config['DEBUG']}")
    print("=" * 60)
    print("\nAvailable endpoints:")
    print("  - GET  /")
    print("  - GET  /api/health")
    print("  - POST /api/auth/register")
    print("  - POST /api/auth/login")
    print("  - POST /api/auth/google")
    print("  - GET  /api/posts")
    print("  - POST /api/posts")
    print("  - GET  /api/posts/<post_id>")
    print("  - POST /api/posts/<post_id>/spotlight")
    print("  - GET  /api/posts/<post_id>/comments")
    print("  - POST /api/posts/<post_id>/comments")
    print("  - GET  /api/search")
    print("  - GET  /api/users/<user_id>")
    print("  - PUT  /api/users/<user_id>")
    print("  - GET  /api/users/<user_id>/profile")
    print("  - GET  /api/users/<user_id>/stats")
    print("  - GET  /api/notifications")
    print("  - GET  /api/notifications/count")
    print("  - DELETE /api/notifications/<notification_id>")
    print("  - DELETE /api/notifications/clear")
    print("  - POST /api/playlists")
    print("  - GET  /api/playlists/user/<user_id>")
    print("  - GET  /api/playlists/<playlist_id>/contents")
    print("  - POST /api/playlists/<playlist_id>/contents")
    print("  - DELETE /api/playlists/<playlist_id>/contents/<content_id>")
    print("  - DELETE /api/playlists/<playlist_id>")
    print("  - GET  /api/playhistory")
    print("  - POST /api/playhistory")
    print("  - DELETE /api/playhistory/clear")
    print("  - GET  /api/playhistory/stats")
    print("=" * 60)
    print("\nPress CTRL+C to quit\n")
    
    app.run(
        host=app.config['HOST'],
        port=app.config['PORT'],
        debug=app.config['DEBUG']
    )
