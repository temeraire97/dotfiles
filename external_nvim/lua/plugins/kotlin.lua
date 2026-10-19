-- Kotlin LSP: fwcd kotlin-language-server 대신 JetBrains 공식 kotlin-lsp.
-- fwcd 1.3.13 은 내장 컴파일러가 Kotlin 2.1.0 이라 2.3 메타데이터 stdlib 을 못 읽어
-- Regex, Unit 등에 "incompatible version of Kotlin" 거짓 에러가 남(uwellnow api, 2026-10-19).
-- 설치는 Homebrew(brew install JetBrains/utils/kotlin-lsp). Alpha, KMP 미지원.
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
}
