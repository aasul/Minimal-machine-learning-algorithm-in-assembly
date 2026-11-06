# assembly

seven months ago, i got into an argument in the comments of [a youtube video](https://youtu.be/eK3_DYA2sNY) showing a basic python program using sqlite. i'm @collector-r7s in that comment section, in case anyone wants to check why this repository exists.

@Sxlect9482 commented "horrid". i replied, "this would take you a week it took me under 2 hours". i thought the demonstrated code was simple. i wasn't announcing the invention of databases.

he told me to "go make a minimal machine learning algorithm in assembly then come back to me before you flex a 30 line python program that does the bare minimum with sqlite".

i wasn't aware that discussing a short sqlite example required that particular qualification. still, i said, "i will literally learn assembly just to prove you wrong just wait". there were considerably easier ways to leave that conversation.

i then spent seven months following through. four months ago, i returned with "i didnt forget you buddy im still working on it". three months ago, i added "dont think i forgot im still working on it bud and ill prove you wrong". i felt the comment section deserved progress reports. i imagine those were useful to everyone trying to watch a python tutorial.

my latest update is "still didnt forget buddy just finished mastering assembly". i have now also supplied the algorithm, since apparently an update alone would leave the sqlite discussion insufficiently supported.

i originally thought the python code was simple. seven months later, i still think the python code was simple. i just have a separate assembly project to maintain now.

i've written a single-layer perceptron entirely in x86-64 assembly. it learns and, or, and nand from zero weights and bias. it cannot learn xor; i included that to check it knows when to stop.

## running it

i build it on linux with nasm, ld, and make. the tests use sh and awk:

```sh
make
./perceptron
make test
```

`./perceptron xor` hits the 100-epoch limit and exits with status 1.

i was told to make a minimal machine learning algorithm in assembly and come back. anyway, here's the assembly.
