def bump(mut uninitialized: Int):
    uninitialized += 1


def twice(x: Int):
    bump(x)


def main():
    twice(1)
