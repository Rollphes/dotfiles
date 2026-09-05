set -gx CARGO_HOME "$HOME/.cargo"
set -gx RUSTUP_HOME "$HOME/.rustup"

if test -d "$CARGO_HOME/bin"
    fish_add_path -g "$CARGO_HOME/bin"
end