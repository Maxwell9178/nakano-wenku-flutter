import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/wkarchive_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/thin_divider.dart';

/// 数据包导出 / 导入的统一交互流程。
///
/// 「我的」页面与「首次初始化」页面共用这里，
/// 保证两处入口的解析、覆盖 / 合并判断完全一致。
class WkArchiveFlow {
  const WkArchiveFlow._();

  // ------------------------------------------------------------ 导出

  /// 导出数据包。
  ///
  /// 返回 true 表示已经成功保存到用户选择的位置，
  /// 返回 false 表示取消或失败（失败会给出提示）。
  static Future<bool> export(
    BuildContext context, {
    bool allowBookSelection = true,
  }) async {
    final BookRepository books = context.read<BookRepository>();
    final WkArchiveService service = context.read<WkArchiveService>();
    final List<Book> allBooks = books.loadAll();

    final _ExportChoice? choice = await _askExportChoice(
      context,
      bookCount: allBooks.length,
      allowBookSelection: allowBookSelection,
    );
    if (choice == null || !context.mounted) {
      return false;
    }

    Set<int>? selectedNumbers;
    if (choice == _ExportChoice.selected) {
      selectedNumbers = await _askBooksForExport(context, allBooks);
      if (selectedNumbers == null || selectedNumbers.isEmpty) {
        return false;
      }
    }

    try {
      final WkArchiveExportResult? result = await service.exportArchive(
        includeBooks: choice != _ExportChoice.basicOnly,
        selectedNumbers: selectedNumbers,
      );
      if (result == null) {
        return false;
      }
      if (!context.mounted) {
        return true;
      }
      showSoftMessage(
        context,
        '已导出 ${result.fileName} · ${result.sizeLabel}',
      );
      return true;
    } on WkArchiveException catch (error) {
      if (context.mounted) {
        showSoftMessage(context, error.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        showSoftMessage(context, '导出失败，请检查存储空间后重试');
      }
      return false;
    }
  }

  static Future<_ExportChoice?> _askExportChoice(
    BuildContext context, {
    required int bookCount,
    required bool allowBookSelection,
  }) {
    return showGlassDialog<_ExportChoice>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassDialogCard(
          title: '导出数据包',
          english: 'EXPORT .WKARCHIVE',
          message: '基础数据包含账号、书籍记录、摘抄、统计与设置；'
              '带上书籍文件后可以用备份直接恢复正文。'
              '${bookCount == 0 ? '\n\n当前还没有书籍，只能导出基础数据。' : ''}',
          actions: <Widget>[
            GlassDialogButton(
              label: '仅导出基础数据',
              primary: bookCount == 0,
              onTap: () =>
                  Navigator.of(dialogContext).pop(_ExportChoice.basicOnly),
            ),
            GlassDialogButton(
              label: '导出数据 + 全部书籍',
              onTap: bookCount == 0
                  ? null
                  : () =>
                      Navigator.of(dialogContext).pop(_ExportChoice.withBooks),
            ),
            if (allowBookSelection && bookCount > 0)
              GlassDialogButton(
                label: '选择书籍导出',
                onTap: () =>
                    Navigator.of(dialogContext).pop(_ExportChoice.selected),
              ),
            GlassDialogButton(
              label: '取消',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  /// 选择要打包的书籍；返回 null 表示取消。
  static Future<Set<int>?> _askBooksForExport(
    BuildContext context,
    List<Book> books,
  ) {
    final Set<int> selected = <int>{
      for (final Book book in books) book.number,
    };
    final Brightness brightness = Theme.of(context).brightness;

    return showGlassDialog<Set<int>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassDialogCard(
          title: '选择书籍',
          english: 'SELECT BOOKS',
          message: '默认全选，取消勾选即可排除对应书籍。',
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              return SizedBox(
                height: 220,
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: books.length,
                  separatorBuilder: (_, __) => ThinDivider(
                    thickness: 0.6,
                    color: AppColors.divider(brightness),
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    final Book book = books[index];
                    final bool checked = selected.contains(book.number);
                    return PressableScale(
                      pressedScale: 0.99,
                      onTap: () {
                        setDialogState(() {
                          if (checked) {
                            selected.remove(book.number);
                          } else {
                            selected.add(book.number);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              checked
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 17,
                              color: checked
                                  ? AppColors.accent(brightness)
                                  : AppColors.textTertiary(brightness),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    book.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textPrimary(brightness),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${book.id} · ${book.wordCountLabel}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      letterSpacing: 0.4,
                                      color:
                                          AppColors.textTertiary(brightness),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: <Widget>[
            GlassDialogButton(
              label: '开始导出',
              primary: true,
              onTap: () => Navigator.of(dialogContext).pop(selected),
            ),
            GlassDialogButton(
              label: '取消',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ 导入

  /// 选择并导入数据包。
  ///
  /// 返回 true 表示已经写入本地数据。
  static Future<bool> import(BuildContext context) async {
    final WkArchiveService service = context.read<WkArchiveService>();

    WkArchivePayload? payload;
    try {
      payload = await service.pickAndRead();
    } on WkArchiveException catch (error) {
      if (context.mounted) {
        showSoftMessage(context, error.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        showSoftMessage(context, '数据包读取失败，请确认文件是否完整');
      }
      return false;
    }

    if (payload == null || !context.mounted) {
      return false;
    }

    final bool? overwrite = await _askImportMode(context, payload);
    if (overwrite == null || !context.mounted) {
      return false;
    }

    try {
      final WkArchiveApplyResult result = await service.apply(
        payload,
        overwrite: overwrite,
      );
      if (!context.mounted) {
        return true;
      }
      final String modeLabel = result.overwrite ? '完全覆盖' : '合并导入';
      showSoftMessage(
        context,
        result.overwrite
            ? '已覆盖导入 ${result.bookCount} 本书'
            : '已合并导入 ${result.bookCount} 本新书',
      );
      if (!result.overwrite && result.bookCount == 0) {
        showSoftMessage(context, '没有新增书籍（同名书籍已跳过）');
      }
      debugPrint('[WkArchive] $modeLabel 完成，头像=${result.hasAvatar}');
      return true;
    } on WkArchiveException catch (error) {
      if (context.mounted) {
        showSoftMessage(context, error.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        showSoftMessage(context, '导入失败，数据包可能已损坏');
      }
      return false;
    }
  }

  static Future<bool?> _askImportMode(
    BuildContext context,
    WkArchivePayload payload,
  ) {
    final String bookLabel = payload.includeBooks
        ? '含 ${payload.bookCount} 本书的正文'
        : '仅基础数据';
    return showGlassDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassDialogCard(
          title: '导入方式',
          english: 'IMPORT MODE',
          message: '备份来自「${payload.userName}」，$bookLabel。\n\n'
              '完全覆盖会清空本机现有的书籍、摘抄与统计；'
              '合并导入会保留现有数据，重复书籍自动跳过。',
          actions: <Widget>[
            GlassDialogButton(
              label: '完全覆盖',
              primary: true,
              danger: true,
              onTap: () => Navigator.of(dialogContext).pop(true),
            ),
            GlassDialogButton(
              label: '合并导入',
              onTap: () => Navigator.of(dialogContext).pop(false),
            ),
            GlassDialogButton(
              label: '取消',
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }
}

/// 导出范围。
enum _ExportChoice { basicOnly, withBooks, selected }
