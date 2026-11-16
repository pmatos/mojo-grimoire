def main():
    var xs: List[Int] = [4, 5, 6]
    var last = xs.pop()
    print(last, len(xs))
    print(xs.pop() + xs.pop(), len(xs))
    xs.append(7)
    print(xs.pop(), len(xs))
