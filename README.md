# skel

skel consists of BASH environment skeleton files and command line helper scripts.

## Install

Open the command line to your home directory and then run the following commands.

* git clone git@github.com:michael-cannon/skel.git .skel
* ~/.skel/bin/shellinks

Existing directories and files will be replaced with `*.bak` as needed. Therefore there's no worry about data loss of your current BASH environment.

## Customization

### `vi` key bindings

I'm a long-time developer that likes to keep his hands on the keyboard and never got into IDEs. Instead, I use vi, a lot. Even worse, my command line uses vi key bindings. If you have no idea about them, then comment out the respective vi lines in `~/.inputrc`.

### Changing `~/.bashrc` Defaults

You're welcome to change `.bashrc` defaults, by adding a custom `~/.bashrc.custom` file in your home directory. This way, you can redefine command line variables or add your personal touches as needed.

Additionally, you can setup a `.bashrc` per computer or server via `~/.bashrc.hostname`. If you're not sure what your computers hostname is, run `hostname` on the command line. Then append that result to `~/.bashrc.` for your own custom `~/.bashrc`.

For my local box, depending upon the network connection, I have two custom `~/.bashrc` files, one called `~/.bashrc.tlf.local` and then a symlink of `~/.bashrc.tlf.fritz.box` to `~/.bashrc.tlf.local`. This way, my local web server information is correct when I reset permissions via `fixwebsitepermissions`.

There's even support for `~/.bashrc.hostname.username`. This is especially useful when your user does sudo or comes in as root via a non-root account.

### Changing `~/.bash_profile` Defaults

Typically, `.bash_profile` is called for interactive shell sessions. However, I find that `.bash_profile` isn't always included when needed. Therefore much of the BASH envrionment settings are handled via `.bashrc`. In anycase, `.bash_profile` is also supported.

Like `.bashrc`, custom `.bash_profile` is supported via `~/.bash_profile.custom`. Additionally `~/.bash_profile.hostname` and `~/.bash_profile.hostname.username` are supported.

### Custom `bin`

If you want to add your own bin files, I would suggest adding them to `~/.skel/bin/custom`. The `~/.bashrc` will automatically detect a `~/.skel/bin/custom` directory and add to `$PATH` ahead of `~/.skel/bin`.

This means you could write your own script like `hackkill`, place it in `~/.skel/bin/custom` and it'll run instead of `~/.skel/bin/hackkill`.

### `alias` Options

I like keeping `alias` scripts broken out by normal, ssh and conditional groupings. As such, there's…
* `.alias` for normal things like `alias ll="ls -l"`
* `.alias.ssh` for `alias alias stypo3vb="ssh typo3vb@typo3vagabond.com"`
* `.alias.conditional` for `alias`'s that are created under certain conditions

You can create your custom alias options in a `~/.alias.custom` file.

## What does `abc`, `123` or `XYZ` do?

Good question, read the script and still not sure, ask me.

## Got Ideas or Complaints? Contact Me

Please provide feedback and suggestions via http://aihr.us/contact-aihrus/.