library;

import 'package:shared_preferences/shared_preferences.dart';

double resultTextSize = 20;

int? globalLeftRightCount;
int? globalDiceCount;
int? globalPointerCount;
int? globalNinjaCount;

Future<void> initializeGlobals() async {
  globalLeftRightCount = await getLeftRightCount() ?? 0;
  globalDiceCount = await getDiceCount() ?? 0;
  globalPointerCount = await getPointerCount() ?? 0;
  globalNinjaCount = await getNinjaCount() ?? 0;
}

Future<int?> getLeftRightCount() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  return preferences.getInt('leftRightCount');
}

Future<int?> getDiceCount() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  return preferences.getInt('diceCount');
}

Future<int?> getPointerCount() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  return preferences.getInt('pointerCount');
}

Future<int?> getNinjaCount() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  return preferences.getInt('ninjaCount');
}

void globalResetData() async {
  SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setInt('leftRightCount', 0);
  await preferences.setInt('diceCount', 0);
  await preferences.setInt('pointerCount', 0);
  await preferences.setInt('ninjaCount', 0);
  await preferences.setStringList('optionList', []);

  globalLeftRightCount = 0;
  globalDiceCount = 0;
  globalPointerCount = 0;
  globalNinjaCount = 0;
}
