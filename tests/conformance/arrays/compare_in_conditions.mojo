def main():
    var a = [1, 2]
    var b = [1, 3]
    if a < b:
        print("lt")
    else:
        print("ge")
    while a == b:
        print("never")
    print(a < b and b > a, a == b or a != b, not (a == [1, 2]))
    print("r", a > [0, 9], (a < b) == True)
