def main():
    var a = [1, 2]
    if a == [[1], [2]]:
        print("eq")
    while [[3], [4]] == a:
        print("never")
    print(not (a != [[1], 2]) and [[1], [2]] <= a)
