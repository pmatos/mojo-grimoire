def flip_both(mut a: Bool, mut b: Bool):
    a = not a
    b = not b


def main():
    var x = True
    flip_both(x, x)
    print(x)
