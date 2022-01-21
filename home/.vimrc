set nocompatible              " be iMproved, required
filetype off                  " required

"##############################
" Plugins handler:
"##############################

   " set the runtime path to include Vundle and initialize
   set rtp+=~/.vim/bundle/Vundle.vim
   call vundle#begin()
   " alternatively, pass a path where Vundle should install plugins
   "call vundle#begin('~/some/path/here')

   " let Vundle manage Vundle, required
   Plugin 'VundleVim/Vundle.vim'
   Plugin 'rhysd/vim-clang-format'
   Plugin 'universal-ctags/ctags'
   Plugin 'ludovicchabant/vim-gutentags'
   Plugin 'sjl/badwolf'
   Plugin 'tpope/vim-fugitive'
   Plugin 'tpope/vim-surround'
   Plugin 'tpope/vim-repeat'
   Plugin 'michaeljsmith/vim-indent-object'
   Plugin 'Syntastic'
   Plugin 'scrooloose/nerdtree' " file drawer, open with :NERDTreeToggle
   Plugin 'Vimjas/vim-python-pep8-indent'
   Plugin 'vim-flake8'
   Plugin 'endel/vim-github-colorscheme'
   Plugin 'SimpylFold'
   Plugin 'L9'
   Plugin 'othree/vim-autocomplpop'
   Plugin 'jreybert/vimagit'
   Plugin 'kana/vim-fakeclip'
   Plugin 'ekalinin/dockerfile.vim'
   Plugin 'junegunn/fzf'
   Plugin 'junegunn/fzf.vim'

   " All of your Plugins must be added before the following line
   call vundle#end()            " required
   filetype plugin indent on    " required
   " To ignore plugin indent changes, instead use:
   "filetype plugin on
   "
   " Brief help
   " :PluginList       - lists configured plugins
   " :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
   " :PluginSearch foo - searches for foo; append `!` to refresh local cache
   " :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
   "
   " see :h vundle for more details or wiki for FAQ
   " Put your non-Plugin stuff after this line
   "

"##############################
" NERDTree File Explorer:
"##############################
   " show hidden files in NERDTree
   let NERDTreeShowHidden=1
   " Opening the file explorer in a vertical split when opening vim
   map <c-k> :NERDTreeToggle<cr>


"##############################
" Numbering Stuff:
"##############################
   set number relativenumber

   augroup numbertoggle
     autocmd!
     autocmd BufEnter,FocusGained,InsertLeave * set relativenumber
     autocmd BufLeave,FocusLost,InsertEnter   * set norelativenumber
   augroup END

   " default the LineNr when entering Vim
   set nu

   " Line numbering conf
   function! InsertLineNr()
      "hi CursorLine cterm=NONE ctermfg=Red ctermbg=Red gui=NONE guifg=Red guibg=Red
      hi LineNr cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=LightGrey guibg=#1c1c1c
      hi CursorLineNr term=bold cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=#ffc400 guibg=#404000
   endfunction

   function! InsertLeaveLineNr()
      hi LineNr cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=LightGrey guibg=#1c1c1c
      hi CursorLineNr term=bold cterm=NONE ctermfg=NONE ctermbg=NONE gui=NONE guifg=#ffc400 guibg=#404000
    endfunction

   call InsertLeaveLineNr()
   autocmd InsertEnter * call InsertLineNr()
   autocmd InsertLeave * call InsertLeaveLineNr()

"##############################
" Mouse Stuff:
"##############################
   set mouse=a
   if has("mouse_sgr")
       set ttymouse=sgr
   else
       set ttymouse=xterm2
   end


"##############################
" Grepping Stuff:
"##############################
   " The Silver Searcher
   if executable('ag')
      " Use ag over grep
      let filtegrep="--ignore=*.html"
      set grepprg=ag\ --nogroup\ --nocolor\ --ignore=*.html

      " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
      let g:ctrlp_user_command = 'ag %s -l --nocolor -g "" --ignore=*.html'

      " ag is fast enough that CtrlP doesn't need to cache
      let g:ctrlp_use_caching = 0
   endif

   nnoremap K :grep! "\b<C-R><C-W>\b"<CR>:cw<CR>

"##############################
" Fuzzy find Stuff:
"##############################
noremap <C-p> :Files<Cr>

"##############################
" Color Stuff:
"##############################
   if &diff
      colorscheme github
   else
      set termguicolors
      let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
      let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
      " For Neovim 0.1.3 and 0.1.4
      let $NVIM_TUI_ENABLE_TRUE_COLOR=1

      " Theme
      syntax enable
      colorscheme badwolf

      " Make the gutters darker than the background.
      let g:badwolf_darkgutter = 1
      " Make the tab line darker than the background.
      let g:badwolf_tabline = 3
      "###############################
   endif

"##############################
" Appearance :
"##############################
   set colorcolumn=110
   highlight ColorColumn ctermbg=darkgray

   set list
   set listchars=tab:▸\ ,trail:·,extends:\#,nbsp:.
   set hlsearch
   set nowrap
   set expandtab
   set formatoptions-=cro
   set tabstop=2 shiftwidth=2 expandtab

   " default the statusline to green when entering Vim
   hi statusline guibg=#0a9dff ctermfg=8 guifg=White ctermbg=15
   " Formats the statusline

   " Puts in the current git status
   set statusline+=%{FugitiveStatusline()}

   " Puts in syntastic warnings
   set statusline+=%#warningmsg#
   set statusline+=%{SyntasticStatuslineFlag()}
   "   set statusline+=%*
   set statusline=%f                           " file name
   "set statusline+=%{&ff}] "file format
   set statusline+=%m      "modified flag
   "set statusline+=%r      "read only flag


   set statusline+=\ %=                        " align left
   "set statusline+=Line:%l/%L[%p%%]            " line X of Y [percent of file]
   "set statusline+=\ Col:%c                    " current column
   set statusline+=\ Buf:%n                    " Buffer number


   " Status line conf
   "
   " orange #ff8a0c
   " blue #0a9dff
   " green #b1d810
   function! InsertStatuslineColor(mode)
      if a:mode == 'i'
         hi statusline guibg=#b1d810 ctermfg=6 guifg=Black ctermbg=0
      elseif a:mode == 'v'
         hi statusline guibg=Purple ctermfg=5 guifg=Black ctermbg=0
      else
         hi statusline guibg=DarkRed ctermfg=1 guifg=White ctermbg=0
      endif
   endfunction


   function! CursorLineNrColorVisual()
       set updatetime=0
       hi statusline guibg=#ff8a0c ctermfg=1 guifg=Black ctermbg=0
       return ''
   endfunction

   function! ResetCursorLineNrColor()
      hi statusline guibg=#0a9dff ctermfg=8 guifg=White ctermbg=15
      return ''
   endfunction

   augroup CursorLineNrColorSwap
       autocmd!
       autocmd InsertEnter * call InsertStatuslineColor(v:insertmode)
       autocmd InsertLeave * call ResetCursorLineNrColor()
       autocmd CursorHold * call ResetCursorLineNrColor()
   augroup END


   vnoremap <expr> <SID>CursorLineNrColorVisual CursorLineNrColorVisual()
           nnoremap <script> v v<SID>CursorLineNrColorVisual
           nnoremap <script> V V<SID>CursorLineNrColorVisual
   nnoremap <script> <C-v> <C-v><SID>CursorLineNrColorVisual


"##############################
" Text Utils Stuff:
"##############################
   set spell spelllang=en_us " spellchecks

"##############################
" Clang Stuff:
"##############################
   let g:clang_format#detect_style_file = 1

"##############################
" Code Navigation Stuff:
"##############################
   " Open the definition in a new tab
   "map <C-\> :tab split<CR>:exec("tag ".expand("<cword>"))<CR>
   " Open the definition in a vertical split ctrl + \
   map <C-\> :bo vsp <CR>:exec("tag ".expand("<cword>"))<CR>

"##############################
"" Ctags Stuff:
"##############################
   set tags=./tags;/


"##############################
"" Folding:
"##############################
   autocmd Syntax c,cpp,vim,xml setlocal foldmethod=syntax
   autocmd Syntax python setlocal foldmethod=indent
   set foldnestmax=2
   set foldlevelstart=20


"##############################
"  Stuff:
"##############################
   " Run clear when exiting vim
   autocmd VimLeave * :!clear

   " Removes trailing spaces
   if !exists('*TrimWhiteSpace')
      function TrimWhiteSpace()
        %s/\s*$//
        ''
      endfunction
   endif

   autocmd FileWritePre * call TrimWhiteSpace()
   autocmd FileAppendPre * call TrimWhiteSpace()
   autocmd FilterWritePre * call TrimWhiteSpace()
   autocmd BufWritePre * call TrimWhiteSpace()

   map <F2> :call TrimWhiteSpace()<CR>
   map! <F2> :call TrimWhiteSpace()<CR>

"##############################
"  Misc:
"##############################
autocmd BufWritePost *.py call Flake8()
" Systastic stuff
let g:syntastic_python_checkers = ['flake8']
let g:syntastic_python_flake8_config_file='~/.config/flake8'
let g:syntastic_python_flake8_args="--max-line-length=320"
let g:flake8_max_line_length=320
let g:syntastic_python_python_exec = 'python3'
let g:syntastic_python_checkers = ['python']
let g:syntastic_mode_map = { 'mode': 'passive',
                          \ 'active_filetypes': [],
                          \ 'passive_filetypes': [] }
let g:syntastic_auto_loc_list=1
nnoremap <silent> <S-f> :SyntasticCheck<CR>
let @r = "import pdb; pdb.set_trace()"
" Syntax coloring
"
au BufNewFile,BufRead Jenkinsfile setf groovy

" Folding
""

" Autocompletion
""
"inoremap <c-x><c-]> <c-]>


" Jump to function
" Csc on the function
function! Csc()
  cscope find c <cword>
  copen
endfunction
command! Csc call Csc()


"##############################
"  Buffers And Tabs:
"##############################
nnoremap <Leader>b :Buffers<CR>

"##############################
"  Buffers And Tabs:
"##############################
noremap <Up> <Nop>
noremap <Down> <Nop>
noremap <Left> <Nop>
noremap <Right> <Nop>
