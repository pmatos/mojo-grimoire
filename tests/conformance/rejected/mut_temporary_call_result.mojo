def one() -> Int:
    return 1


def bump(mut x: Int):
    x += 1


def main():
    bump(one())
    print("bumped")
