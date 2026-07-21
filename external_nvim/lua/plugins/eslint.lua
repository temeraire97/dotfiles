-- ESLint LSP: monorepo per-package cwd 해석.
-- workingDirectories=auto → 파일별 nearest package dir 를 cwd 로 잡아
-- 각 파일이 자기 eslint.config.ts(+올바른 tsconfig root)를 쓰게 함.
-- editup monorepo 처럼 workspace 마다 다른 flat config 일 때 필수.
-- (extension 파일에 proofreader-ui 의 projectService config 가 잘못 적용되어
--  "No tsconfigRootDir / multiple candidate roots" 파싱 에러 나던 것 해소.)
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        eslint = {
          settings = {
            workingDirectories = { mode = "auto" },
          },
        },
      },
    },
  },
}
