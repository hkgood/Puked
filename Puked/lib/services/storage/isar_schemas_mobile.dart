import 'package:isar/isar.dart';
import '../../models/db_models.dart';

const List<CollectionSchema<dynamic>> allIsarSchemas = [
  TripSchema,
  TrajectoryPointSchema,
  RecordedEventSchema,
  BrandSchema,
  SoftwareVersionSchema
];
