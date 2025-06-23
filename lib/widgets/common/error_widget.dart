import 'package:flutter/material.dart';
import 'custom_button.dart';

class CustomErrorWidget extends StatelessWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onRetry;
  final String? retryText;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final bool showIcon;
  final Color? iconColor;
  final TextStyle? titleStyle;
  final TextStyle? messageStyle;

  const CustomErrorWidget({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.onRetry,
    this.retryText,
    this.action,
    this.padding,
    this.showIcon = true,
    this.iconColor,
    this.titleStyle,
    this.messageStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: padding ?? const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Icon(
              icon ?? Icons.error_outline,
              size: 48,
              color: iconColor ?? theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
          ],
          if (title != null) ...[
            Text(
              title!,
              style: titleStyle ?? theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],
          Flexible(
            child: Text(
              message,
              style: messageStyle ?? theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 16),
          if (action != null)
            action!
          else if (onRetry != null)
            CustomButton(
              text: retryText ?? '重试',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
            ),
        ],
      ),
    );
  }
}

class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;
  final EdgeInsetsGeometry? padding;

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
    this.message,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      title: '网络连接失败',
      message: message ?? '请检查您的网络连接后重试',
      icon: Icons.wifi_off,
      onRetry: onRetry,
      retryText: '重新连接',
      padding: padding,
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String? title;
  final String message;
  final IconData? icon;
  final VoidCallback? onAction;
  final String? actionText;
  final Widget? action;
  final EdgeInsetsGeometry? padding;
  final Color? iconColor;

  const EmptyStateWidget({
    super.key,
    this.title,
    required this.message,
    this.icon,
    this.onAction,
    this.actionText,
    this.action,
    this.padding,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return CustomErrorWidget(
      title: title,
      message: message,
      icon: icon ?? Icons.inbox_outlined,
      iconColor: iconColor ?? theme.colorScheme.onSurface,
      onRetry: onAction,
      retryText: actionText,
      action: action,
      padding: padding,
    );
  }
}

class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? message;
  final EdgeInsetsGeometry? padding;

  const ServerErrorWidget({
    super.key,
    this.onRetry,
    this.message,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      title: '服务器错误',
      message: message ?? '服务器暂时无法响应，请稍后重试',
      icon: Icons.dns_outlined,
      onRetry: onRetry,
      padding: padding,
    );
  }
}

class UnauthorizedErrorWidget extends StatelessWidget {
  final VoidCallback? onLogin;
  final String? message;
  final EdgeInsetsGeometry? padding;

  const UnauthorizedErrorWidget({
    super.key,
    this.onLogin,
    this.message,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      title: '未授权访问',
      message: message ?? '您的登录已过期，请重新登录',
      icon: Icons.lock_outline,
      onRetry: onLogin,
      retryText: '重新登录',
      padding: padding,
    );
  }
}

class NotFoundErrorWidget extends StatelessWidget {
  final VoidCallback? onGoBack;
  final String? message;
  final EdgeInsetsGeometry? padding;

  const NotFoundErrorWidget({
    super.key,
    this.onGoBack,
    this.message,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return CustomErrorWidget(
      title: '页面不存在',
      message: message ?? '您访问的页面不存在或已被删除',
      icon: Icons.search_off,
      onRetry: onGoBack,
      retryText: '返回',
      padding: padding,
    );
  }
}

class ErrorDialog extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String? confirmText;
  final String? cancelText;
  final bool barrierDismissible;
  final IconData? icon;
  final Color? iconColor;

  const ErrorDialog({
    super.key,
    this.title,
    required this.message,
    this.onConfirm,
    this.onCancel,
    this.confirmText,
    this.cancelText,
    this.barrierDismissible = true,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: 48,
              color: iconColor ?? theme.colorScheme.error,
            )
          : null,
      title: title != null ? Text(title!) : null,
      content: Text(
        message,
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        if (onCancel != null)
          CustomTextButton(
            text: cancelText ?? '取消',
            onPressed: onCancel,
          ),
        CustomTextButton(
          text: confirmText ?? '确定',
          onPressed: onConfirm ?? () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    String? title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool barrierDismissible = true,
    IconData? icon,
    Color? iconColor,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        barrierDismissible: barrierDismissible,
        icon: icon,
        iconColor: iconColor,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: cancelText != null
            ? () => Navigator.of(context).pop(false)
            : null,
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String? confirmText;
  final String? cancelText;
  final bool isDangerous;
  final IconData? icon;

  const ConfirmDialog({
    super.key,
    this.title,
    required this.message,
    this.onConfirm,
    this.onCancel,
    this.confirmText,
    this.cancelText,
    this.isDangerous = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      icon: icon != null
          ? Icon(
              icon,
              size: 48,
              color: isDangerous
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            )
          : null,
      title: title != null ? Text(title!) : null,
      content: Text(
        message,
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        CustomTextButton(
          text: cancelText ?? '取消',
          onPressed: onCancel ?? () => Navigator.of(context).pop(false),
        ),
        if (isDangerous)
          CustomTextButton(
            text: confirmText ?? '确定',
            onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
            foregroundColor: theme.colorScheme.error,
          )
        else
          CustomTextButton(
            text: confirmText ?? '确定',
            onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    String? title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isDangerous = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDangerous: isDangerous,
        icon: icon,
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}