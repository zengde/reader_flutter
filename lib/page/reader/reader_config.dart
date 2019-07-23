import 'package:flutter/painting.dart';
import 'package:reader_flutter/util/constants.dart';

class ReaderConfig {

  static ReaderConfig _instance;
  static ReaderConfig get instance {
    if (_instance == null) {
      _instance = ReaderConfig();
    }
    return _instance;
  }

  double letterSpacing = 2.0;
  double lineHeight = 1.5;
  double titleFontSize = 14.0;
  double contentFontSize = 18.0;
  bool isDayMode = true;

  Color get textColor{
    return isDayMode
                    ? AppColors.DayModeTextColor
                    : AppColors.NightModeTextColor;
  }

  Color get bgColor{
    return isDayMode
                    ? AppColors.DayModeBgColor
                : AppColors.NightModeBgColor;
  }

  Color get btnColor{
    return isDayMode
                    ? AppColors.DayModeIconTitleButtonColor
              : AppColors.NightModeIconTitleButtonColor;
  }

  Color get menuBgColor{
    return isDayMode
                    ? AppColors.DayModeMenuBgColor
            : AppColors.NightModeMenuBgColor;
  }
  Color get inactiveTrackColor{
    return isDayMode
                    ? AppColors.DayModeInactiveTrackColor
                        : AppColors.NightModeInactiveTrackColor;
  }
  Color get activeTrackColor{
    return isDayMode
                    ? AppColors.DayModeActiveTrackColor
                        : AppColors.NightModeActiveTrackColor;
  }
  Color get thumbColor{
    return isDayMode
                    ? AppColors.DayModeActiveTrackColor
                        : AppColors.NightModeActiveTrackColor;
  }
}