def both(mut a: Int, mut b: Int):
    a += 1
    b += 1


def main():
    var x = 1
    both(x, x)
    print(x)
