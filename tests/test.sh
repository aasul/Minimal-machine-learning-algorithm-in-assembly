#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
    echo "test failed: $*" >&2
    exit 1
}

check() {
    # Recalculate each pass from the truth table, then check the printed model.
    awk -v mode="$2" '
    function die(msg) {
        print "line " NR ": " msg > "/dev/stderr"
        bad = 1
        exit 1
    }
    function label(x, y) {
        if (gate == "and") return x && y
        if (gate == "or") return x || y
        if (gate == "nand") return !(x && y)
        return x != y
    }
    function finish() {
        if (gate == "") return
        if (!initial || !status || rows != 4 || ep == 0) die("incomplete run")
        if (mode == "normal" && (!changed1 || !changed2 || !changedb))
            die("weights and bias must change during training")
    }
    /^(and|or|nand|xor)$/ {
        finish()
        gate = $0
        gates++
        if (mode == "xor") {
            if (gate != "xor" || gates != 1) die("expected xor")
        } else {
            split("and or nand", order, " ")
            if (gate != order[gates]) die("wrong gate order")
        }
        initial = status = rows = ep = 0
        changed1 = changed2 = changedb = 0
        w1 = w2 = bias = 0
        next
    }
    /^initial w1=0 w2=0 bias=0$/ {
        if (gate == "" || initial || ep) die("unexpected initial state")
        initial = 1
        next
    }
    /^epoch [0-9]+ errors=[0-9]+ w1=-?[0-9]+ w2=-?[0-9]+ bias=-?[0-9]+$/ {
        if (!initial || status || (ep && errors == 0)) die("unexpected epoch")
        if ($2 != ++ep) die("epoch order")
        errors = 0
        for (i = 0; i < 4; i++) {
            x = int(i / 2)
            y = i % 2
            pred = (w1*x + w2*y + bias >= 0)
            err = label(x, y) - pred
            if (err != 0) errors++
            w1 += err*x
            w2 += err*y
            bias += err
        }
        if ($3 != "errors=" errors || $4 != "w1=" w1 ||
            $5 != "w2=" w2 || $6 != "bias=" bias) die("incorrect learning update")
        if (w1 != 0) changed1 = 1
        if (w2 != 0) changed2 = 1
        if (bias != 0) changedb = 1
        next
    }
    /^converged$/ {
        if (mode != "normal" || status || !ep || errors != 0)
            die("false convergence")
        if (ep > 100) die("epoch limit exceeded")
        status = 1
        next
    }
    /^nonconvergence after [0-9]+ epochs$/ {
        limit = (mode == "short" ? 1 : 100)
        if (mode == "normal" || status || ep != limit || $3 != limit || !errors)
            die("incorrect nonconvergence")
        status = 1
        next
    }
    /^[01] [01] -> [01] [(]want [01][)]$/ {
        if (!status || rows >= 4) die("unexpected prediction")
        x = int(rows / 2)
        y = rows % 2
        if ($1 != x || $2 != y) die("wrong inputs")
        target = $6
        sub(/[)]$/, "", target)
        pred = (w1*x + w2*y + bias >= 0)
        if (target != label(x, y) || $4 != pred) die("incorrect inference")
        if (mode == "normal" && $4 != target) die("wrong learned prediction")
        rows++
        next
    }
    /^$/ { next }
    { die("unexpected output: " $0) }
    END {
        if (bad) exit 1
        finish()
        if (gates != (mode == "normal" ? 3 : 1)) die("missing gate")
    }
    ' "$1" || fail "$2 output"
}

./perceptron > "$tmp/first"
./perceptron > "$tmp/second"
cmp "$tmp/first" "$tmp/second" || fail 'normal run is not reproducible'
check "$tmp/first" normal

status=0
./perceptron xor > "$tmp/xor" || status=$?
[ "$status" -eq 1 ] || fail "xor exited with $status"
status=0
./perceptron xor > "$tmp/xor-again" || status=$?
[ "$status" -eq 1 ] || fail "repeated xor exited with $status"
cmp "$tmp/xor" "$tmp/xor-again" || fail 'xor run is not reproducible'
check "$tmp/xor" xor

"${NASM:-nasm}" -f elf64 -Werror -DMAX_EPOCHS=1 -o "$tmp/short.o" main.asm
"${LD:-ld}" -o "$tmp/short" "$tmp/short.o"
status=0
"$tmp/short" > "$tmp/short-out" || status=$?
[ "$status" -eq 1 ] || fail "epoch limit exited with $status"
check "$tmp/short-out" short

# Success on the last allowed pass must still count as convergence.
"${NASM:-nasm}" -f elf64 -Werror -DMAX_EPOCHS=6 -o "$tmp/last.o" main.asm
"${LD:-ld}" -o "$tmp/last" "$tmp/last.o"
"$tmp/last" > "$tmp/last-out"
check "$tmp/last-out" normal

for arg in '' x xo xorr AND --help; do
    status=0
    ./perceptron "$arg" > "$tmp/out" 2> "$tmp/err" || status=$?
    [ "$status" -eq 2 ] || fail "invalid argument exited with $status"
    [ ! -s "$tmp/out" ] || fail 'usage went to stdout'
    [ "$(cat "$tmp/err")" = 'usage: perceptron [xor]' ] || fail 'missing usage'
done
status=0
./perceptron xor extra > "$tmp/out" 2> "$tmp/err" || status=$?
[ "$status" -eq 2 ] || fail 'extra arguments accepted'

if [ -c /dev/full ]; then
    status=0
    ./perceptron > /dev/full || status=$?
    [ "$status" -eq 1 ] || fail 'output failure was ignored'
fi

echo 'all tests passed'
