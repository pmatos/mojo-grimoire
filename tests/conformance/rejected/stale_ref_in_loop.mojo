def main():
    var xs: List[Int] = [1]
    ref head = xs[0]
    var i = 0
    while i < 3:
        print(head)
        xs.append(i)
        i += 1
