// Emits the actual production schema for the standalone Python SQLite checks.
import 'dart:convert';

import 'dart:io';

import 'package:cielo_rd/core/database/schema_v1.dart';

void main() => stdout.writeln(jsonEncode(schemaV1Statements));
