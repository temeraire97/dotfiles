return {
  -- LazyVim의 기본 explorer는 snacks.nvim 입니다 (<leader>e).
  -- snacks explorer는 내부적으로 picker 이므로 picker.sources.explorer 를 덮어씁니다.
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true, -- "."으로 시작하는 dotfile 표시
            ignored = true, -- .gitignore에 포함된 파일도 표시 (원치 않으면 false)
          },
        },
        -- (선택) <leader>ff 등 파일 찾기에서도 dotfile을 보이게 하려면:
        -- sources = {
        --   files = { hidden = true },
        -- },
      },
    },
  },
}
