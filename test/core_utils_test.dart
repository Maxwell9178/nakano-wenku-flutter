import 'package:flutter_test/flutter_test.dart';
import 'package:nakanowenku/core/constants/app_constants.dart';
import 'package:nakanowenku/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

void main() {
  group('书籍编号', () {
    test('按四位补零生成 NW-XXXX', () {
      expect(AppConstants.formatBookId(1), 'NW-0001');
      expect(AppConstants.formatBookId(27), 'NW-0027');
      expect(AppConstants.formatBookId(9999), 'NW-9999');
    });

    test('越界编号被收敛到合法区间', () {
      expect(AppConstants.formatBookId(0), 'NW-0001');
      expect(AppConstants.formatBookId(12000), 'NW-9999');
    });
  });

  group('颜色工具', () {
    test('alpha 将 0~1 映射到 0~255', () {
      expect(AppColors.alpha(Colors.black, 0).alpha, 0);
      expect(AppColors.alpha(Colors.black, 1).alpha, 255);
      expect(AppColors.alpha(Colors.black, 0.5).alpha, 128);
    });

    test('透明度越界会被收敛', () {
      expect(AppColors.alpha(Colors.white, -1).alpha, 0);
      expect(AppColors.alpha(Colors.white, 2).alpha, 255);
    });
  });
}
