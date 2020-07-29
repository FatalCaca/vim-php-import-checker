" php use checker
" Maintainer:   simon.ballu@gmail.com
" Version:      0.1

function FetchImportedClasses()
    let file = readfile(expand("%:p"))
    let importedClasses = []

    for line in file
        let mainClassDeclaration = matchstr(line, '\v^class')

        if (!empty(mainClassDeclaration))
            break
        endif

        let matches = matchlist(line, '\v^use .*\\%(\w+ +as +)?(\w+);')
        let className = get(matches, 1, '0')

        if (className != '0')
            :call add(importedClasses, className)
        endif
    endfor

    return importedClasses
endfunction

function DoesNeighbourClassExist(className)
    let currentPath = expand('%:p:h')
    let potentialNeighbourClassFile = currentPath . '/' . a:className . '.php'

    if filereadable(potentialNeighbourClassFile)
        let file = readfile(expand(potentialNeighbourClassFile))

        for line in file
            if (!empty(matchstr(line, '\v^(abstract +)?(class|interface|trait) +' . a:className)))
                return 1
            endif
        endfor
    endif

    return 0
endfunction

function RunAsyncFunctionIfPossible(functionName)
    if v:version < 800
        :call a:functionName()
        return
    endif

    :call timer_start(1, a:functionName)
endfunction

function ClearMatchGroup(groupName)
    for m in filter(getmatches(), { i, v -> l:v.group is? a:groupName})
        :call matchdelete(m.id)
    endfor
endfunction

function HighlightUnusedUses(timer)
    normal! mq
    let importedClasses = FetchImportedClasses()
    :highlight UnusedImportsGroup ctermbg=brown guibg=brown
    :call ClearMatchGroup('UnusedImportsGroup')

    for class in importedClasses
        if (
            \ [0, 0] == searchpos('\vnew +' . class)
            \ && [0, 0] == searchpos('\v' . class . '::')
            \ && [0, 0] == searchpos('\v' . class . ' +\$\w*')
            \ && [0, 0] == searchpos('\v\@' . class)
            \ && [0, 0] == searchpos('\vclass.*(extends|implements).*' . class)
            \ && [0, 0] == searchpos('\vuse *' . class)
            \ )
            :call matchadd('UnusedImportsGroup', '\v^use .*' . class . ';')
        endif
    endfor

    normal! 'q
endfunction
" }}}

" Highlight classes whose import can't be found {{{
function HighlightUnimportedClasses(timer)
    let classNameRegex = '[A-Z][a-zA-Z0-9_]*'
    :highlight Classes ctermbg=red guibg=red
    :call ClearMatchGroup('Classes')

    let file = readfile(expand("%:p"))
    let usedClasses = {}
    let mainClassFound = 0
    let lineIndex = 0

    for line in file
        let lineIndex += 1
        let mainClassDeclaration = matchstr(line, '\v^(class|trait|interface)')

        if (!empty(mainClassDeclaration))
            let mainClassFound = 1
        endif

        if !mainClassFound
            continue
        endif

        for classPattern in [
            \ '\C\v(new +)@<=' . classNameRegex,
            \ '\C\v' . classNameRegex . '(::)@=',
            \ '\C\v' . classNameRegex . '( +\$\w*)@=',
            \ '\C\v\@@<=' . classNameRegex,
            \ '\C\v(class.*(extends|implements) *)@<=' . classNameRegex,
            \ '\C\v(use *)@<=' . classNameRegex . ';',
            \ '\C\v(\) *: *)@<=' . classNameRegex,
            \ '\C\v^( *: *)@<=' . classNameRegex,
        \ ]
            let reducedLine = line
            let matchPos = matchstrpos(reducedLine, classPattern)

            while matchPos[0] != ''
                let className = matchPos[0]
                let classNameLength = strlen(className)

                if !has_key(usedClasses, className)
                    let usedClasses[className] = []
                endif

                call add(
                    \ usedClasses[className],
                    \ [lineIndex, matchPos[1] + 1, classNameLength]
                \ )

                let blanks = repeat(' ', strlen(className))
                let reducedLine =
                    \ strpart(reducedLine, 0, matchPos[1])
                    \ . blanks
                    \ . strpart(reducedLine, matchPos[1] + classNameLength)

                let matchPos = matchstrpos(reducedLine, classPattern)
            endwhile
        endfor
    endfor

    let importedClasses = FetchImportedClasses()

    for [className, classPositions] in items(usedClasses)
        if index(importedClasses, className) == -1
            \ && !DoesNeighbourClassExist(className)

            :call matchaddpos('Classes', classPositions)
        endif
    endfor
endfunction
