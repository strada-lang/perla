/*
 * perla_moose_xs.c — Perla implementation of Moose.xs / mop.c
 *
 * This replaces the Perl XS module that Moose normally provides.
 * It implements the same 30 INSTALL_SIMPLE_READER accessors using
 * Perla's StradaValue/perla_code_set API instead of Perl's newXS/CV.
 *
 * The original mop.c does:
 *   INSTALL_SIMPLE_READER(Class, instance_metaclass)
 * which creates an XS function that reads $self->{instance_metaclass}.
 *
 * We do the equivalent:
 *   perla_code_set("Class::MOP::Class", "instance_metaclass", accessor_fn)
 * where accessor_fn reads the hash key from the first arg.
 */

#include "strada_runtime.h"
#include "perla_stash.h"
#include <string.h>

/* Generic hash-key reader: reads $self->{key} where key is determined
 * by the function's registration. We use a table of reader functions,
 * one per key, since C function pointers can't carry closure data. */

/* Forward declare the accessor generator */
static StradaValue *_mop_read_key(StradaValue *args, const char *key);

/* Macro to generate a named reader function for each key */
#define MOP_READER(cname, key_str) \
    static StradaValue *mop_read_##cname(StradaValue *args) { \
        return _mop_read_key(args, key_str); \
    }

/* Generate reader functions for all 34 MOP keys */
MOP_READER(name, "name")
MOP_READER(package, "package")
MOP_READER(package_name, "package_name")
MOP_READER(body, "body")
MOP_READER(accessor, "accessor")
MOP_READER(reader, "reader")
MOP_READER(writer, "writer")
MOP_READER(predicate, "predicate")
MOP_READER(clearer, "clearer")
MOP_READER(builder, "builder")
MOP_READER(init_arg, "init_arg")
MOP_READER(initializer, "initializer")
MOP_READER(default_val, "default")
MOP_READER(definition_context, "definition_context")
MOP_READER(insertion_order, "insertion_order")
MOP_READER(is_inline, "is_inline")
MOP_READER(associated_class, "associated_class")
MOP_READER(associated_metaclass, "associated_metaclass")
MOP_READER(associated_methods, "associated_methods")
MOP_READER(attribute_metaclass, "attribute_metaclass")
MOP_READER(attributes, "attributes")
MOP_READER(method_metaclass, "method_metaclass")
MOP_READER(wrapped_method_metaclass, "wrapped_method_metaclass")
MOP_READER(instance_metaclass, "instance_metaclass")
MOP_READER(immutable_trait, "immutable_trait")
MOP_READER(constructor_class, "constructor_class")
MOP_READER(constructor_name, "constructor_name")
MOP_READER(destructor_class, "destructor_class")
MOP_READER(methods, "methods")
MOP_READER(_expected_method_class, "_expected_method_class")
MOP_READER(operator, "operator")
MOP_READER(_package_cache_flag, "_package_cache_flag")
MOP_READER(version, "version")

/* The generic reader implementation */
static StradaValue *_mop_read_key(StradaValue *args, const char *key) {
    StradaArray *av = args ? strada_deref_array(args) : NULL;
    if (!av || strada_array_length(av) < 1) return strada_new_undef();
    StradaValue *self = strada_array_get(av, 0);
    if (!self || STRADA_IS_TAGGED_INT(self)) return strada_new_undef();
    /* Deref if it's a reference */
    StradaValue *target = self;
    if (self->type == STRADA_REF && self->value.rv && !STRADA_IS_TAGGED_INT(self->value.rv))
        target = self->value.rv;
    if (target->type != STRADA_HASH) return strada_new_undef();
    StradaValue *val = strada_hv_fetch_owned(target, key);
    if (!val) return strada_new_undef();
    /* For _attribute_map and _method_map: if the value is a hash ref,
     * return the inner hash so that $self->_attribute_map->{$name} = $attr
     * stores into the right place (strada_hv_store needs a HASH, not REF) */
    if (val->type == STRADA_REF && val->value.rv && !STRADA_IS_TAGGED_INT(val->value.rv)
        && val->value.rv->type == STRADA_HASH) {
        StradaValue *inner = val->value.rv;
        strada_incref(inner);
        strada_decref(val);
        return inner;
    }
    return val;
}

/* Install all MOP readers — equivalent to the BOOT sections in Moose's XS files */
void perla_moose_xs_boot(void) {
    /* From Package.xs: INSTALL_SIMPLE_READER_WITH_KEY(Package, name, package) */
    perla_code_set("Class::MOP::Package", "name", strada_cpointer_new((void*)mop_read_package));

    /* From Class.xs */
    perla_code_set("Class::MOP::Class", "instance_metaclass", strada_cpointer_new((void*)mop_read_instance_metaclass));
    perla_code_set("Class::MOP::Class", "immutable_trait", strada_cpointer_new((void*)mop_read_immutable_trait));
    perla_code_set("Class::MOP::Class", "constructor_class", strada_cpointer_new((void*)mop_read_constructor_class));
    perla_code_set("Class::MOP::Class", "constructor_name", strada_cpointer_new((void*)mop_read_constructor_name));
    perla_code_set("Class::MOP::Class", "destructor_class", strada_cpointer_new((void*)mop_read_destructor_class));

    /* From Instance.xs */
    perla_code_set("Class::MOP::Instance", "associated_metaclass", strada_cpointer_new((void*)mop_read_associated_metaclass));

    /* From Method.xs */
    perla_code_set("Class::MOP::Method", "name", strada_cpointer_new((void*)mop_read_name));
    perla_code_set("Class::MOP::Method", "package_name", strada_cpointer_new((void*)mop_read_package_name));
    perla_code_set("Class::MOP::Method", "body", strada_cpointer_new((void*)mop_read_body));

    /* From AttributeCore.xs */
    perla_code_set("Class::MOP::Mixin::AttributeCore", "name", strada_cpointer_new((void*)mop_read_name));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "accessor", strada_cpointer_new((void*)mop_read_accessor));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "reader", strada_cpointer_new((void*)mop_read_reader));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "writer", strada_cpointer_new((void*)mop_read_writer));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "predicate", strada_cpointer_new((void*)mop_read_predicate));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "clearer", strada_cpointer_new((void*)mop_read_clearer));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "builder", strada_cpointer_new((void*)mop_read_builder));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "init_arg", strada_cpointer_new((void*)mop_read_init_arg));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "initializer", strada_cpointer_new((void*)mop_read_initializer));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "definition_context", strada_cpointer_new((void*)mop_read_definition_context));
    perla_code_set("Class::MOP::Mixin::AttributeCore", "insertion_order", strada_cpointer_new((void*)mop_read_insertion_order));

    /* From HasAttributes.xs */
    perla_code_set("Class::MOP::Mixin::HasAttributes", "attribute_metaclass", strada_cpointer_new((void*)mop_read_attribute_metaclass));
    perla_code_set("Class::MOP::Mixin::HasAttributes", "_attribute_map", strada_cpointer_new((void*)mop_read_attributes));

    /* From HasMethods.xs */
    perla_code_set("Class::MOP::Mixin::HasMethods", "method_metaclass", strada_cpointer_new((void*)mop_read_method_metaclass));
    perla_code_set("Class::MOP::Mixin::HasMethods", "wrapped_method_metaclass", strada_cpointer_new((void*)mop_read_wrapped_method_metaclass));

    /* From Generated.xs */
    perla_code_set("Class::MOP::Method::Generated", "is_inline", strada_cpointer_new((void*)mop_read_is_inline));
    perla_code_set("Class::MOP::Method::Generated", "definition_context", strada_cpointer_new((void*)mop_read_definition_context));

    /* From Attribute.xs */
    perla_code_set("Class::MOP::Attribute", "associated_class", strada_cpointer_new((void*)mop_read_associated_class));
    perla_code_set("Class::MOP::Attribute", "associated_methods", strada_cpointer_new((void*)mop_read_associated_methods));

    /* From Inlined.xs */
    perla_code_set("Class::MOP::Method::Inlined", "_expected_method_class", strada_cpointer_new((void*)mop_read__expected_method_class));

    /* Also register for Moose::Meta:: subclasses (they inherit from Class::MOP) */
    perla_code_set("Moose::Meta::Class", "instance_metaclass", strada_cpointer_new((void*)mop_read_instance_metaclass));
    perla_code_set("Moose::Meta::Class", "immutable_trait", strada_cpointer_new((void*)mop_read_immutable_trait));
    perla_code_set("Moose::Meta::Class", "constructor_class", strada_cpointer_new((void*)mop_read_constructor_class));
    perla_code_set("Moose::Meta::Class", "constructor_name", strada_cpointer_new((void*)mop_read_constructor_name));
    perla_code_set("Moose::Meta::Class", "destructor_class", strada_cpointer_new((void*)mop_read_destructor_class));
    perla_code_set("Moose::Meta::Class", "attribute_metaclass", strada_cpointer_new((void*)mop_read_attribute_metaclass));
    perla_code_set("Moose::Meta::Class", "method_metaclass", strada_cpointer_new((void*)mop_read_method_metaclass));
    perla_code_set("Moose::Meta::Class", "wrapped_method_metaclass", strada_cpointer_new((void*)mop_read_wrapped_method_metaclass));
    perla_code_set("Moose::Meta::Class", "name", strada_cpointer_new((void*)mop_read_package));
    perla_code_set("Moose::Meta::Role", "name", strada_cpointer_new((void*)mop_read_package));
    perla_code_set("Class::MOP::Module", "name", strada_cpointer_new((void*)mop_read_package));
}
