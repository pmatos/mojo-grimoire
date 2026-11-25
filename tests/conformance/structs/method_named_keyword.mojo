struct S(Movable):
    var n: Int
    def __init__(out self):
        self.n = 1
    def pass(self):
        pass
    def return(self) -> Int:
        return self.n
    def while(self) -> Int:
        var i = 0
        while i < 2:
            i += 1
        return i
def main():
    var s = S()
    s.pass()
    print(s.return(), s.while())
