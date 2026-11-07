export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
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
    'subject-case': [0],
    'subject-max-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 100],
    'body-max-line-length': [1, 'always', 100],
  },
};
