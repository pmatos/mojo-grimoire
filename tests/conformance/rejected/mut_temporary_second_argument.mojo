def add(mut x: Int, y: Int):
    x += y


def main():
    var x = 1
    add(x, 2)
    add(3, x)
    print(x)
