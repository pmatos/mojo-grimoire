def pick(ref x: Int) -> ref[x] Int:
    return x


def bump(mut x: Int):
    x += 1


def main():
    bump(pick(1))
    print("bumped")
