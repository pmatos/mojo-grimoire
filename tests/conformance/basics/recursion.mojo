def fact(n: Int) -> Int:
    if n <= 1:
        return 1
    return n * fact(n - 1)


def fib(n: Int) -> Int:
    if n < 2:
        return n
    return fib(n - 1) + fib(n - 2)


def main():
    print(fact(10), fib(15))
