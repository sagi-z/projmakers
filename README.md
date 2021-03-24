# Projmakers

Auto create makeprg commands per project.
  
## Description

Add simple entries to your [projectionist] json file to define make commands
which set the *:compiler* and optionally also override the *makeprg*.

## Dependencies

* Required -    [projectionist].
* Recommended - [dispatch].

## Install

### Either with plug.vim

Of course make sure [projectionist] is installed:

```vim
Plug 'tpope/vim-projectionist'
```

And also add this plugin:

```vim
Plug 'sagi-z/projmakers'
```

### Or Manual

* Install [projectionist].
* Install this plugin:

```text
:!git clone https://github.com/sagi-z/projmakers ~/.vim/plugin/projmakers
```

## Usage by example

(See also [projectionist] for the '.projections.json' file).

Lets assume you're using a *./test.sh* script for testing, which runs several
*pytest* executables (with different session setups), and you want to use it as
the testsuite for the project.
All you need in order to automatically create a main **:ProjTestSuite** command
and some helper commands which use this script is to add this to your
*.projections.json* file:

```json
  {
    ...
    "*": {
        "makeprgs": {
            "ProjTestSuite" : {
                "compiler": "pytest",
                "makeprg": "{project}/test.sh",
                "args": "--all --short -- -v",
                "complete": [
                        "--all",
                        "--allow-fail",
                        "--report",
                        "--coverage",
                        "--clean",
                        "--refresh-req",
                        "--no-reinstall",
                        "--short",
                        "--medium",
                        "test_client",
                        "test_commons",
                        "test_mocked_client",
                        "test_mocked_server",
                        "test_server"
                ]
            },
            "ProjTestMockedClient" : {
                "compiler": "pytest",
                "makeprg": "{project}/test.sh",
                "args": "-- -v test_mocked_client"
            },
            "ProjTestMockedServer" : {
                "compiler": "pytest",
                "makeprg": "{project}/test.sh",
                "args": "-- -v test_mocked_server"
            }
            ...
        }
        ...
  }
```

Other projects can have a different *:compiler* and *makeprgs* associated
with the same command.

Now when a buffer is loaded and a *.projections.json* file is loaded for it, a
new **:ProjTestSuite** command will be defined in this buffer to use the
compiler and makeprg and invoke *:Make* if [dispatch] is installed or *:make*
otherwise (of course **:ProjTestMockedClient** and **:ProjTestMockedServer**
commands are created the same way as defined in the json file).

If you supply options on the vim command line then they replace the *args* in
the json file.

To sum up:

* Add a *"makeprgs"* dictionary entry to files in your *.projections.json* file.
* In this dictionary add your command dictionaries: a dictionary per command
  to create.
* Each command dictionary will cause a command to be created for the current
  buffer of the relevant file, when loaded.
* Each new command must have a *"compiler"* defined for it.
* Each new command can optionally override the *"makeprg"* which the
  *:compiler* sets.
* Each new command can optionally supply an *"args"* string which will be used as
  default arguments to the *"makeprg"* if none are supplied.
* Each new command can optionally supply a *"complete"* list or string which
  will be used to help the user complete arguments for the command.

## More help

For the most up to date docs use [:help projmakers](doc/projmakers.txt)

## License

MIT

[projectionist]:        https://github.com/tpope/vim-projectionist
[dispatch]:             https://github.com/tpope/vim-dispatch
[projmakers]:           https://github.com/sagi-z/projmakers
