def add_into(mut a: Int, b: Int):
    a += b
    print("b is", b)


def main():
    var x = 1
    add_into(x, x)
    print(x)
