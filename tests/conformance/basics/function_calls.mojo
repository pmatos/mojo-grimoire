def square(x: Int) -> Int:
    return x * x


def sum_of_squares(a: Int, b: Int) -> Int:
    return square(a) + square(b)


def main():
    print(sum_of_squares(3, 4))
