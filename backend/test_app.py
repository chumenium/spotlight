import unittest
import json
from app import app, db, Post, SearchHistory

class TestSpotlightAPI(unittest.TestCase):
    def setUp(self):
        """テストのセットアップ"""
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.app = app.test_client()
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        """テストのクリーンアップ"""
        with app.app_context():
            db.session.remove()
            db.drop_all()
    
    def test_create_post(self):
        """投稿作成のテスト"""
        response = self.app.post('/api/posts', 
                               data=json.dumps({
                                   'title': 'テスト投稿',
                                   'content': 'テストコンテンツ',
                                   'author': 'テストユーザー'
                               }),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['title'], 'テスト投稿')
        self.assertEqual(data['content'], 'テストコンテンツ')
        self.assertEqual(data['author'], 'テストユーザー')
    
    def test_get_posts(self):
        """投稿取得のテスト"""
        # テストデータの作成
        with app.app_context():
            post = Post(title='テスト投稿', content='テストコンテンツ', author='テストユーザー')
            db.session.add(post)
            db.session.commit()
        
        response = self.app.get('/api/posts')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['title'], 'テスト投稿')
    
    def test_get_post_by_id(self):
        """IDによる投稿取得のテスト"""
        with app.app_context():
            post = Post(title='テスト投稿', content='テストコンテンツ', author='テストユーザー')
            db.session.add(post)
            db.session.commit()
            post_id = post.id
        
        response = self.app.get(f'/api/posts/{post_id}')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['title'], 'テスト投稿')
    
    def test_update_post(self):
        """投稿更新のテスト"""
        with app.app_context():
            post = Post(title='元のタイトル', content='元のコンテンツ', author='テストユーザー')
            db.session.add(post)
            db.session.commit()
            post_id = post.id
        
        response = self.app.put(f'/api/posts/{post_id}',
                              data=json.dumps({
                                  'title': '更新されたタイトル',
                                  'content': '更新されたコンテンツ'
                              }),
                              content_type='application/json')
        
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['title'], '更新されたタイトル')
        self.assertEqual(data['content'], '更新されたコンテンツ')
    
    def test_delete_post(self):
        """投稿削除のテスト"""
        with app.app_context():
            post = Post(title='削除対象', content='削除対象コンテンツ', author='テストユーザー')
            db.session.add(post)
            db.session.commit()
            post_id = post.id
        
        response = self.app.delete(f'/api/posts/{post_id}')
        self.assertEqual(response.status_code, 200)
        
        # 削除されたことを確認
        response = self.app.get(f'/api/posts/{post_id}')
        self.assertEqual(response.status_code, 404)
    
    def test_add_search_history(self):
        """検索履歴追加のテスト"""
        response = self.app.post('/api/search-history',
                               data=json.dumps({
                                   'query': 'Flutter チュートリアル',
                                   'user_id': 'user123'
                               }),
                               content_type='application/json')
        
        self.assertEqual(response.status_code, 201)
        data = json.loads(response.data)
        self.assertEqual(data['query'], 'Flutter チュートリアル')
        self.assertEqual(data['user_id'], 'user123')
    
    def test_get_search_history(self):
        """検索履歴取得のテスト"""
        with app.app_context():
            history = SearchHistory(query='テストクエリ', user_id='user123')
            db.session.add(history)
            db.session.commit()
        
        response = self.app.get('/api/search-history?user_id=user123')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['query'], 'テストクエリ')
    
    def test_health_check(self):
        """ヘルスチェックのテスト"""
        response = self.app.get('/api/health')
        self.assertEqual(response.status_code, 200)
        data = json.loads(response.data)
        self.assertEqual(data['status'], 'healthy')

if __name__ == '__main__':
    unittest.main()