def main():
    var a = False
    if a < True:
        print("lt")
    while a < True:
        a = True
        print("loop")
    print(not (a > False), (a < a) or (a >= a))
