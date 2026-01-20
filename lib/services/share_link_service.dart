import '../config/app_config.dart';
import 'playlist_service.dart';

class ShareLinkService {
  static String buildPostDeepLink(String postId) {
    return 'spotlight://content/$postId';
  }

  static String buildPlaylistDeepLink(int playlistId) {
    return 'spotlight://playlist/$playlistId';
  }

  static String buildPostWebLink(String postId) {
    return '${AppConfig.backendUrl}/content/$postId';
  }

  static String buildPlaylistWebLink(int playlistId) {
    return '${AppConfig.backendUrl}/playlist/$playlistId';
  }

  static String buildPostShareText(String title, String postId) {
    final deepLink = buildPostDeepLink(postId);
    final webLink = buildPostWebLink(postId);
    return '$title\n$deepLink\n$webLink';
  }

  static String buildPlaylistShareText(Playlist playlist) {
    final deepLink = buildPlaylistDeepLink(playlist.playlistid);
    final webLink = buildPlaylistWebLink(playlist.playlistid);
    return '${playlist.title}\n$deepLink\n$webLink';
  }
}
