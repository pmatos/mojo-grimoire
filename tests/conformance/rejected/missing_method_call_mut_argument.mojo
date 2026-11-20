def bump(mut k: Int):
    k += 1


def f() -> Int:
    return 1


def main():
    var f = 1
    bump(f())
    print(f)
