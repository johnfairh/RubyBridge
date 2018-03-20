//
//  rbg_helpers.m
//  RubyGatewayHelpers
//
//  Distributed under the MIT license, see LICENSE
//

@import CRuby;
#import "rbg_helpers.h"
#import <stdbool.h>
#import <stdint.h>

// Fixups for Ruby < 2.3

#ifndef RB_NUM2LONG
#define RB_NUM2LONG NUM2LONG
#endif

#ifndef RB_FIX2LONG
#define RB_FIX2LONG FIX2LONG
#endif

#ifndef RB_FIX2ULONG
#define RB_FIX2ULONG FIX2ULONG
#endif

#ifndef RUBY_FL_USER1
#define RUBY_FL_USER1 FL_USER1
#endif

//
// # Thunks for Exception Handling
//
// If there is an unhandled exception then Ruby crashes the process.
// We elect to never let this occur via RubyGateway APIs.
//
// The way to handle an exception in the C API is to wrap the throwy
// call in `rb_protect()`.
//
// (`rb_rescue()` does not handle all exceptions and the varargs `rb_rescue2()`
// doesn't make it through the clang importer so we'd need this kind of code
// anyway.)
//
//
// The normal flow goes:
//
//   client_1 -> rb_protect              // call from client code
//
//         client_2 <- rb_protect        // call from Ruby to client-provided throwy code
//
//            client_2 -> rb_something   // throwy call
//
//            client_2 <- rb_something   // unwind
//
//         client_2 -> rb_protect        // unwind
//
//   client_1 <- rb_protect              // unwind
//
//
// The exception flow goes:
//
//   client_1 -> rb_protect              // call from client code, Ruby does setjmp()
//
//         client_2 <- rb_protect        // call from Ruby to client-provided throwy code
//
//            client_2 -> rb_something   // throwy call
//
//                        rb_something   // EXCEPTION - longjump()
//
//   client_1 <- rb_protect              // unwind
//
// So, the key difference is that the bottom part of `client_2` and its return
// to rb_protect is skipped.
//
// Swift does not handle this: it assumes all functions will run to completion,
// or the process will exit.
//
// So we cannot implement `client_2` in Swift.  This file contains the implementations
// of `client_2` in regular C that is totally happy to be longjmp()d over.
//

// Just use a single type with a cookie to pass params down the stack.
// I had a lovely version using blocks but then tried to build it on Linux ;-(

typedef enum {
    RBG_JOB_LOAD,
    RBG_JOB_INTERN,
    RBG_JOB_CONST_GET,
    RBG_JOB_CONST_GET_AT,
    RBG_JOB_FUNCALLV,
    RBG_JOB_BLOCK_CALL_PVOID,
    RBG_JOB_BLOCK_CALL_VALUE,
    RBG_JOB_CVAR_GET,
    RBG_JOB_TO_ULONG,
    RBG_JOB_TO_LONG,
    RBG_JOB_TO_DOUBLE,
    RBG_JOB_PROC_CALL,
} Rbg_job;

typedef struct {
    Rbg_job       job;

    VALUE         value;
    ID            id;

    bool          loadWrap;
    const char   *internName;
    int           argc;
    const VALUE  *argv;
    double        toDoubleResult;
    void         *blockContext;
    VALUE         blockArg;
} Rbg_protect_data;

#define RBG_PDATA_TO_VALUE(pdata) ((uintptr_t)(void *)(pdata))
#define RBG_VALUE_TO_PDATA(value) ((Rbg_protect_data *)(void *)(uintptr_t)(value))

static VALUE rbg_obj2ulong(VALUE v);

static VALUE rbg_block_pvoid_callback(VALUE yieldedArg, VALUE callbackArg,
                                      int argc, VALUE *argv, VALUE blockArg);
static VALUE rbg_block_value_callback(VALUE yieldedArg, VALUE callbackArg,
                                      int argc, VALUE *argv, VALUE blockArg);

/// Callback made by Ruby from `rb_protect` -- OK to raise exceptions from here.
static VALUE rbg_protect_thunk(VALUE value)
{
    Rbg_protect_data *d = RBG_VALUE_TO_PDATA(value);
    VALUE rc = Qundef;

    switch (d->job)
    {
    case RBG_JOB_LOAD:
        rb_load(d->value, d->loadWrap);
        break;
    case RBG_JOB_INTERN:
        rc = (VALUE) rb_intern(d->internName);
        break;
    case RBG_JOB_CONST_GET:
        rc = rb_const_get(d->value, d->id);
        break;
    case RBG_JOB_CONST_GET_AT:
        rc = rb_const_get_at(d->value, d->id);
        break;
    case RBG_JOB_FUNCALLV:
        rc = rb_funcallv(d->value, d->id, d->argc, d->argv);
        break;
    case RBG_JOB_BLOCK_CALL_PVOID:
        rc = rb_block_call(d->value, d->id, d->argc, d->argv,
                           rbg_block_pvoid_callback, (VALUE) d->blockContext);
        break;
    case RBG_JOB_BLOCK_CALL_VALUE:
        rc = rb_block_call(d->value, d->id, d->argc, d->argv,
                           rbg_block_value_callback, (VALUE) d->blockContext);
        break;
    case RBG_JOB_CVAR_GET:
        rc = rb_cvar_get(d->value, d->id);
        break;
    case RBG_JOB_TO_ULONG:
        rc = rbg_obj2ulong(d->value);
        break;
    case RBG_JOB_TO_LONG:
        rc = (VALUE) RB_NUM2LONG(rb_Integer(d->value));
        break;
    case RBG_JOB_TO_DOUBLE:
        d->toDoubleResult = NUM2DBL(rb_Float(d->value));
        break;
    case RBG_JOB_PROC_CALL:
        rc = rb_proc_call_with_block(d->value, d->argc, d->argv, d->blockArg);
        break;
    }
    return rc;
}

/// Run the job described by `data` and report exception status in `status`.
static VALUE rbg_protect(Rbg_protect_data * _Nonnull data, int * _Nullable status)
{
    return rb_protect(rbg_protect_thunk, RBG_PDATA_TO_VALUE(data), status);
}

// rb_load -- rb_load_protect exists but doesn't protect against exceptions
// raised by the file being loaded, just the filename lookup part.
void rbg_load_protect(VALUE fname, int wrap, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_LOAD, .value = fname, .loadWrap = wrap };

    // rb_load_protect has another bug, if you send it null status
    // then it accesses the pointer anyway.  Recent regression, will try to fix...
    int tmpStatus = 0;
    if (status == NULL)
    {
        status = &tmpStatus;
    }

    (void) rbg_protect(&data, status);
}

// rb_intern - can technically run out of IDs....
ID rbg_intern_protect(const char * _Nonnull name, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_INTERN, .internName = name };
    return (ID) rbg_protect(&data, status);
}

// rb_const_get - raises if not found
VALUE rbg_const_get_protect(VALUE value, ID id, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_CONST_GET, .value = value, .id = id };
    return rbg_protect(&data, status);
}

// rb_const_get_at - raises if not found
VALUE rbg_const_get_at_protect(VALUE value, ID id, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_CONST_GET_AT, .value = value, .id = id };
    return rbg_protect(&data, status);
}

// rb_inspect - raises if can't get a string out
VALUE rbg_inspect_protect(VALUE value, int * _Nullable status)
{
    return rb_protect(rb_inspect, value, status);
}

// rb_funcallv - run arbitrary code
VALUE rbg_funcallv_protect(VALUE value, ID id,
                           int argc, const VALUE * _Nonnull argv,
                           int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_FUNCALLV, .value = value, .id = id,
                              .argc = argc, .argv = argv };
    return rbg_protect(&data, status);
}

// rb_block_call - run two lots of arbitrary code
VALUE rbg_block_call_pvoid_protect(VALUE value, ID id,
                                   int argc, const VALUE * _Nonnull argv,
                                   void * _Nonnull context,
                                   int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_BLOCK_CALL_PVOID, .value = value, .id = id,
                              .argc = argc, .argv = argv,
                              .blockContext = context };
    return rbg_protect(&data, status);
}

// rb_block_call - run two lots of arbitrary code
VALUE rbg_block_call_value_protect(VALUE value, ID id,
                                   int argc, const VALUE * _Nonnull argv,
                                   VALUE context,
                                   int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_BLOCK_CALL_VALUE, .value = value, .id = id,
                              .argc = argc, .argv = argv,
                              .blockContext = (void *) context };
    return rbg_protect(&data, status);
}

// rb_cvar_get - raises if you look at it funny
VALUE rbg_cvar_get_protect(VALUE clazz, ID id, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_CVAR_GET, .value = clazz, .id = id };
    return rbg_protect(&data, status);
}

// rb_String - raises if it can't get a string out.
VALUE rbg_String_protect(VALUE v, int * _Nullable status)
{
    return rb_protect(rb_String, v, status);
}

//
// Integer numeric conversion
//
// Ruby allows implicit signed -> unsigned conversion which is too
// slapdash for the Swift interface.  This seems to be remarkably
// baked into Ruby's numerics, so we do some 'orrible rooting around
// to figure it out.
//

static int rbg_numeric_ish_type(VALUE v)
{
    return NIL_P(v) ||
           FIXNUM_P(v) ||
           RB_TYPE_P(v, T_FLOAT) ||
           RB_TYPE_P(v, T_BIGNUM);
}

static VALUE rbg_obj2ulong(VALUE v)
{
    // Drill down to find something we can actually compare to zero.
    while (!rbg_numeric_ish_type(v))
    {
        v = rb_Integer(v);
    }

    // Now decide if this looks negative
    bool negative = false;

    if (FIXNUM_P(v))
    {
        negative = (RB_FIX2LONG(v) < 0);
    }
    else if (RB_TYPE_P(v, T_FLOAT))
    {
        negative = (NUM2DBL(v) < 0);
    }
    else if (RB_TYPE_P(v, T_BIGNUM))
    {   // don't @ me
        negative = ((RBASIC(v)->flags & RUBY_FL_USER1) == 0);
    }

    if (negative)
    {
        rb_raise(rb_eTypeError, "Value is negative and cannot be expressed as unsigned.");
    }

    return rb_num2ulong(v);
}

// rb_obj2ulong - raises if can't do conversion
unsigned long rbg_obj2ulong_protect(VALUE v, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_TO_ULONG, .value = v };
    return rbg_protect(&data, status);
}

// rb_num2long etc. - raises if can't do conversion
long rbg_obj2long_protect(VALUE v, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_TO_LONG, .value = v };
    return rbg_protect(&data, status);
}

// rb_Float - raises if can't do conversion.
double rbg_obj2double_protect(VALUE v, int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_TO_DOUBLE, .value = v };
    rbg_protect(&data, status);
    return data.toDoubleResult;
}

// rb_proc_call - arbitrary code
VALUE rbg_proc_call_with_block_protect(VALUE value,
                                       int argc, const VALUE * _Nonnull argv,
                                       VALUE blockArg,
                                       int * _Nullable status)
{
    Rbg_protect_data data = { .job = RBG_JOB_PROC_CALL, .value = value,
        .argc = argc, .argv = argv, .blockArg = blockArg };
    return rbg_protect(&data, status);
}

//
// Procs/blocks written in Swift
//
// Indirection here to allow Swift code to raise Ruby exceptions by
// passing status back to this C layer which then uses the Ruby API
// to actually do the raising.
//

/// Registered Swift callbacks.
///
/// These are registered instead of passed per-call to avoid running
/// out of context space.
///
/// Two separate callbacks for the two cases where we want to call a
/// Swift callback -- the pvoid-context case -- and where we want to
/// call a Ruby VALUE block -- the value-context case.

/// This is `rbproc_pvoid_block_callback` in RbProc.swift.
static Rbg_pvoid_block_call rbg_pvoid_block_call;

/// This is `rbproc_value_block_callback` in RbProc.swift.
static Rbg_value_block_call rbg_value_block_call;

void rbg_register_pvoid_block_proc_callback(Rbg_pvoid_block_call callback)
{
    rbg_pvoid_block_call = callback;
}

void rbg_register_value_block_proc_callback(Rbg_value_block_call callback)
{
    rbg_value_block_call = callback;
}

/// All block/proc callbacks come into these functions from Ruby core.
///
/// We get in the way to let the Swift implementation do its thing and
/// get safely off the callstack, passing back to us what it wants to
/// do next.  Then we can either pass the result back to Ruby or
/// invoke some API function to longjmp off somewhere else without
/// skipping over any Swift frames.

static VALUE rbg_block_callback_tail(Rbg_return_value * _Nonnull rv);

static VALUE rbg_block_pvoid_callback(VALUE yieldedArg,
                                      VALUE callbackArg,
                                      int argc,
                                      VALUE *argv,
                                      VALUE blockArg)
{
    Rbg_return_value return_value = { 0 };

    rbg_pvoid_block_call((void *) callbackArg, argc, argv, blockArg, &return_value);

    return rbg_block_callback_tail(&return_value);
}

static VALUE rbg_block_value_callback(VALUE yieldedArg,
                                      VALUE callbackArg,
                                      int argc,
                                      VALUE *argv,
                                      VALUE blockArg)
{
    Rbg_return_value return_value = { 0 };

    rbg_value_block_call(callbackArg, argc, argv, blockArg, &return_value);

    return rbg_block_callback_tail(&return_value);
}

static VALUE rbg_block_callback_tail(Rbg_return_value * _Nonnull rv)
{
    switch (rv->type)
    {
    case RBG_RT_VALUE:
        return rv->value;
    case RBG_RT_BREAK:
        rb_iter_break();    /* does not return */
    case RBG_RT_BREAK_VALUE:
        rb_iter_break_value(rv->value);   /* does not return */
    case RBG_RT_RAISE:
        rb_exc_raise(rv->value);    /* does not return */
    default:
        rb_raise(rb_eRuntimeError, "Mangled Swift retval from proc: %u", rv->type);
    }
}
