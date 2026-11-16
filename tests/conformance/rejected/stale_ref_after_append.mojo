def main():
    var xs: List[Int] = [1, 2]
    ref second = xs[1]
    xs.append(3)
    print(second)
