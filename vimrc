source ~/.vim/configuration.vim
source ~/.vim/coc-settings.vim
source ~/.vim/airline.vim
source ~/.vim/folding.vim
source ~/.vim/git.vim
source ~/.vim/nerdtree.vim
source ~/.vim/treesitter.lua
source ~/.vim/windows.vim
source ~/.vim/moves.vim
source ~/.fzf/plugin/fzf.vim
source ~/.vim/fzf.vim
source ~/.vim/custom-highlights.vim
source ~/.vim/custom-mappings.vim
source ~/.vim/blamer.vim
source ~/.vim/nvim-tree.lua

nmap <C-t> :NvimTreeToggle<CR>
nnoremap <leader>r :NvimTreeRefresh<CR>
nnoremap <leader>t :NvimTreeFindFile<CR>

autocmd BufEnter * ++nested if winnr('$') == 1 && bufname() == 'NvimTree_' . tabpagenr() | quit | endif

" nnoremap <silent><leader>l :BufferLineCycleNext<CR>
" nnoremap <silent><leader>h :BufferLineCyclePrev<CR>

" nnoremap <silent><leader>1 <Cmd>BufferLineGoToBuffer 1<CR>
" nnoremap <silent><leader>2 <Cmd>BufferLineGoToBuffer 2<CR>
" nnoremap <silent><leader>3 <Cmd>BufferLineGoToBuffer 3<CR>
" nnoremap <silent><leader>4 <Cmd>BufferLineGoToBuffer 4<CR>
" nnoremap <silent><leader>5 <Cmd>BufferLineGoToBuffer 5<CR>
" nnoremap <silent><leader>6 <Cmd>BufferLineGoToBuffer 6<CR>
" nnoremap <silent><leader>7 <Cmd>BufferLineGoToBuffer 7<CR>
" nnoremap <silent><leader>8 <Cmd>BufferLineGoToBuffer 8<CR>
" nnoremap <silent><leader>9 <Cmd>BufferLineGoToBuffer 9<CR>
