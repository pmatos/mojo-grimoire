def main():
    var xs: List[Int] = [10, 20, 30]
    xs.append(40)
    xs[1] = 21
    print(len(xs), xs[0], xs[1], xs[3])
