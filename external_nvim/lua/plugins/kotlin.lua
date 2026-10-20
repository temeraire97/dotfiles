-- Kotlin LSP: fwcd kotlin-language-server 대신 JetBrains 공식 kotlin-lsp.
-- fwcd 1.3.13 은 내장 컴파일러가 Kotlin 2.1.0 이라 2.3 메타데이터 stdlib 을 못 읽어
-- Regex, Unit 등에 "incompatible version of Kotlin" 거짓 에러가 남(uwellnow api, 2026-10-19).
-- 설치는 Homebrew(brew install JetBrains/utils/kotlin-lsp). Alpha, KMP 미지원.
-- 포맷은 ktfmt kotlinlang 스타일(uwellnow api 의 Spotless 설정과 같음, 2026-10-20).
-- kotlin-lsp 는 IntelliJ 포매터라 ktfmt 와 결과가 달라서 conform 이 ktfmt 만 쓰게 한다.
-- brew 의 ktfmt 버전이 프로젝트 libs.versions.toml 의 ktfmt 와 다르면 저장할 때 diff 가 생긴다.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        kotlin_language_server = { enabled = false },
        kotlin_lsp = {
          mason = false,
          cmd = { "kotlin-lsp", "--stdio" },
        },
      },
    },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        kotlin = { "ktfmt", lsp_format = "never" },
      },
      formatters = {
        ktfmt = { prepend_args = { "--kotlinlang-style" } },
      },
    },
  },
}
