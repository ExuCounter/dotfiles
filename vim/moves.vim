" Accelerated move
let g:accelerated_jk_acceleration_limit = 500 

nmap j <Plug>(accelerated_jk_gj)
nmap k <Plug>(accelerated_jk_gk)

let g:accelerated_jk_acceleration_table = [30,60,90]
let g:comfortable_motion_no_default_key_mappings = 1

" nnoremap <silent> <C-d> :call comfortable_motion#flick(150)<CR>
" nnoremap <silent> <C-u> :call comfortable_motion#flick(-150)<CR>

" let g:comfortable_motion_impulse_multiplier = 1  " Feel free to increase/decrease this value.
" nnoremap <silent> <C-d> :call comfortable_motion#flick(g:comfortable_motion_impulse_multiplier * winheight(0) * 2)<CR>
" nnoremap <silent> <C-u> :call comfortable_motion#flick(g:comfortable_motion_impulse_multiplier * winheight(0) * -2)<CR>

" let g:comfortable_motion_friction = 80.0
" let g:comfortable_motion_air_drag = 10.0

" Disable Arrow keys in Normal mode
map <up> <nop>
map <down> <nop>
map <left> <nop>
map <right> <nop>

" Disable Arrow keys in Insert mode
imap <up> <nop>
imap <down> <nop>
imap <left> <nop>
imap <right> <nop>

" Move lines by alt + arrows
nnoremap ∆ :m .+1<CR>==
nnoremap ˚ :m .-2<CR>==
inoremap ∆ <Esc>:m .+1<CR>==gi
inoremap ˚ <Esc>:m .-2<CR>==gi
vnoremap ∆ :m '>+1<CR>gv=gv
vnoremap ˚ :m '<-2<CR>gv=gv

nmap <silent> <C-u> :lua require('neoscroll').scroll(-14, true, 130)<CR>
nmap <silent> <C-d> :lua require('neoscroll').scroll(14, true, 130)<CR>
