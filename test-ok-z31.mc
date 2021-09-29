//OPIS: inkrement u numexp-u
//RETURN: 53

unsigned y;

unsigned main() {
    unsigned x;
    x = 2u;
    y = 6u;
    y = x++ + y++ + 42u;
    return x + y;
}

