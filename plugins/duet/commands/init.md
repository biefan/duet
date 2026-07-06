---
description: 给当前项目做一次性 duet 设置——git 仓库 + 默认 gitignore(含 __pycache__ 等运行时产物)+ duet 运行时忽略。幂等,可重复跑。新项目/首次在某项目用 duet 时跑一次。
allowed-tools: Bash
---

运行 duet 项目初始化(幂等):

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/duet-init.sh"
```

把脚本输出原样呈现给用户。这一步会:建 git 仓库(如需)、写入 duet 默认 `.gitignore` 块(`__pycache__/`、`*.py[cod]`、`.pytest_cache/`、`.mypy_cache/`、`.ruff_cache/`、`.DS_Store`,以及 duet 自身运行时文件)、建 `.duet/.gitignore`——让运行时产物不进 diff / 提交。
