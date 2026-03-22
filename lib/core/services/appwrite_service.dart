import 'package:appwrite/appwrite.dart';
import 'package:boxed_app/core/constants/appwrite_constants.dart';

class AppwriteService {
  static final Client _client = Client()
    ..setEndpoint(AppwriteConstants.endpoint)
    ..setProject(AppwriteConstants.projectId)
    ..setSelfSigned(status: false);

  static Client get client => _client;
  static Account get account => Account(_client);
  static Databases get databases => Databases(_client);
  static Storage get storage => Storage(_client);
  static Avatars get avatars => Avatars(_client);
}