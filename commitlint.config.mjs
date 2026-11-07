/**
 * Commitlint 配置（自包含，不依赖 @commitlint/config-conventional）
 *
 * 之所以内联规则而不 extends 外部预设：CI 通过 npx 直接调用 commitlint，
 * 不安装 node_modules，外部预设无法被解析。规则含义与
 * @commitlint/config-conventional 等价，额外收紧了 scope 白名单。
 */
export default {
  rules: {
    // type 必须来自白名单
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'refactor',
        'perf',
        'test',
        'docs',
        'ci',
        'chore',
        'build',
        'revert',
      ],
    ],

    // scope 越界只警告，便于新增模块时渐进调整
    'scope-enum': [
      1,
      'always',
      [
        // 后端模块
        'iam',
        'organization',
        'authorization',
        'im',
        'workflow',
        'attendance',
        'announcement',
        'bot',
        'platform',
        'connector',
        'realtime',
        'worker',
        // 数据与契约
        'db',
        'api',
        // 客户端
        'web',
        'flutter',
        // 工程
        'ci',
        'deps',
        'deploy',
        'docs',
        'release',
        'security',
      ],
    ],

    // ─── 结构 ───────────────────────────────────────────────
    'type-empty': [2, 'never'],
    'type-case': [2, 'always', 'lower-case'],
    'scope-empty': [0],
    'scope-case': [2, 'always', 'lower-case'],
    'subject-empty': [2, 'never'],
    'subject-full-stop': [2, 'never', '.'],
    'subject-max-length': [2, 'always', 72],
    'subject-case': [0], // 允许中文与首字母大写

    // ─── 长度 ───────────────────────────────────────────────
    'header-max-length': [2, 'always', 100],
    'body-max-line-length': [1, 'always', 100],
    'footer-max-line-length': [1, 'always', 100],

    // ─── 空行 ───────────────────────────────────────────────
    'body-leading-blank': [2, 'always'],
    'footer-leading-blank': [2, 'always'],
  },
};
