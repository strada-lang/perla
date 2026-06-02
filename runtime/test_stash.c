/* Quick smoke test for perla stash */
#include "perla_stash.h"
#include <stdio.h>
#include <assert.h>

int main(void) {
    perla_init();

    /* Test: create package and store scalar */
    perla_scalar_set("main", "x", strada_new_int(42));
    StradaValue *x = perla_scalar_get("main", "x");
    assert(strada_to_int(x) == 42);
    printf("OK: scalar store/fetch\n");

    /* Test: code slot */
    perla_code_set("Foo", "hello", strada_new_str("placeholder"));
    StradaValue *code = perla_code_get("Foo", "hello");
    assert(code != NULL);
    printf("OK: code store/fetch\n");

    /* Test: stash exists */
    assert(perla_stash_exists("main"));
    assert(perla_stash_exists("Foo"));
    assert(!perla_stash_exists("Bar"));
    printf("OK: stash_exists\n");

    /* Test: @ISA */
    perla_isa_push("Dog", "Animal");
    assert(perla_isa_check("Dog", "Animal"));
    assert(perla_isa_check("Dog", "Dog"));
    assert(!perla_isa_check("Dog", "Cat"));
    printf("OK: @ISA push/check\n");

    /* Test: multi-level ISA */
    perla_isa_push("Puppy", "Dog");
    assert(perla_isa_check("Puppy", "Dog"));
    assert(perla_isa_check("Puppy", "Animal"));
    printf("OK: multi-level ISA\n");

    /* Test: method resolution through ISA */
    perla_code_set("Animal", "speak", strada_new_str("animal_speak"));
    StradaValue *m = perla_method_lookup("Puppy", "speak");
    assert(m != NULL);
    printf("OK: method resolution through ISA chain\n");

    /* Test: local (dynamic scoping) */
    perla_scalar_set("main", "y", strada_new_int(100));
    int mark = perla_save_mark();
    perla_save_scalar("main", "y");
    /* After save, y is undef */
    perla_scalar_set("main", "y", strada_new_int(999));
    assert(strada_to_int(perla_scalar_get("main", "y")) == 999);
    /* Restore */
    perla_restore(mark);
    assert(strada_to_int(perla_scalar_get("main", "y")) == 100);
    printf("OK: local/dynamic scoping\n");

    /* Test: glob lookup by fully qualified name */
    perla_scalar_set("MyPkg", "var", strada_new_str("hello"));
    PerlGlob *g = perla_glob_lookup("MyPkg::var");
    assert(g != NULL);
    assert(g->slots[PERLA_SLOT_SCALAR] != NULL);
    printf("OK: glob_lookup qualified name\n");

    /* Test: stash_keys */
    StradaValue *keys = perla_stash_keys("main");
    assert(keys != NULL);
    printf("OK: stash_keys returned %d keys\n", (int)keys->value.av->size);
    strada_decref(keys);

    /* Test: can */
    assert(perla_can("Puppy", "speak"));
    assert(!perla_can("Puppy", "nonexistent"));
    printf("OK: can()\n");

    /* Test: special variables */
    StradaValue *rs = perla_special_get("/");
    char *rs_str = strada_to_str(rs);
    assert(strcmp(rs_str, "\n") == 0);
    free(rs_str);
    printf("OK: special vars ($/ = \\n)\n");

    perla_cleanup();
    printf("\nAll stash tests passed!\n");
    return 0;
}
