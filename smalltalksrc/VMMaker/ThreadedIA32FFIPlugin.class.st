"
This subclass is for the IA32/x86 ABI.
"
Class {
	#name : #ThreadedIA32FFIPlugin,
	#superclass : #ThreadedFFIPlugin,
	#category : #'VMMaker-Plugins-FFI'
}

{ #category : #translation }
ThreadedIA32FFIPlugin class >> identifyingPredefinedMacros [
	^#('_M_I386' '_M_IX86' '_X86_' 'i386' 'i486' 'i586' 'i686' '__i386__' '__386__' 'X86' 'I386')
]

{ #category : #translation }
ThreadedIA32FFIPlugin class >> moduleName [
	^'IA32FFIPlugin'
]

{ #category : #'callout support' }
ThreadedIA32FFIPlugin >> ffiCalloutTo: procAddr SpecOnStack: specOnStack in: calloutState [
	<var: #procAddr type: #'void *'>
	<var: #calloutState type: #'CalloutState *'>
	"Go out, call this guy and create the return value.  This *must* be inlined because of
	 the alloca of the outgoing stack frame in ffiCall:WithFlags:NumArgs:Args:AndTypes:"
	| myThreadIndex atomicType floatRet intRet |
	<var: #floatRet type: #double>
	<var: #intRet type: #usqLong>
	<inline: true>
	myThreadIndex := interpreterProxy disownVM: (self disownFlagsFor: calloutState).

	(self allocaLiesSoSetSpBeforeCall or: [self mustAlignStack]) ifTrue:
		[self setsp: calloutState argVector].

	atomicType := self atomicTypeOf: calloutState ffiRetHeader.
	(atomicType >> 1) = (FFITypeSingleFloat >> 1) ifTrue:
		[floatRet := self dispatchFunctionPointer: (self cCoerceSimple: procAddr to: 'double (*)()').

		 "undo any callee argument pops because it may confuse stack management with the alloca."
		 (self isCalleePopsConvention: calloutState callFlags) ifTrue:
			[self setsp: calloutState argVector].
		 interpreterProxy ownVM: myThreadIndex.

		 ^interpreterProxy floatObjectOf: floatRet].

	intRet := self dispatchFunctionPointer: (self cCoerceSimple: procAddr to: 'usqLong (*)()').

	"undo any callee argument pops because it may confuse stack management with the alloca."
	(self isCalleePopsConvention: calloutState callFlags) ifTrue:
		[self setsp: calloutState argVector].
	interpreterProxy ownVM: myThreadIndex.

	(calloutState ffiRetHeader anyMask: FFIFlagPointer+FFIFlagStructure) ifTrue:
		["Note: Order is important here since FFIFlagPointer + FFIFlagStructure is used to represent
		 'typedef void* VoidPointer' and VoidPointer must be returned as pointer *not* as struct."
		 (calloutState ffiRetHeader anyMask: FFIFlagPointer) ifTrue:
			[^self ffiReturnPointer: intRet ofType: (self ffiReturnType: specOnStack) in: calloutState].
		 ^self ffiReturnStruct: intRet ofType: (self ffiReturnType: specOnStack) in: calloutState].
	
	^self ffiCreateIntegralResultOop: intRet ofAtomicType: atomicType in: calloutState
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushDoubleFloat: value in: calloutState [
	<var: #value type: #double>
	<var: #calloutState type: #'CalloutState *'>
	<inline: #always>
	calloutState currentArg + 8 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy storeFloatAtPointer: calloutState currentArg from: value.
	calloutState currentArg: calloutState currentArg + 8.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushPointer: pointer in: calloutState [
	<var: #pointer type: #'void *'>
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: pointer.
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSignedByte: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'signed char').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSignedChar: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'signed char').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSignedInt: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: value.
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSignedLongLong: value in: calloutState [
	<var: #value type: #usqLong>
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 8 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy
		longAt: calloutState currentArg put: (self cCoerceSimple: value to: #usqInt);
		longAt: calloutState currentArg + 4 put: (self cCoerceSimple: value >> 32 to: #usqInt).
	calloutState currentArg: calloutState currentArg + 8.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSignedShort: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'signed short').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushSingleFloat: value in: calloutState [
	<var: #value type: #float>
	<var: #calloutState type: #'CalloutState *'>
	<inline: #always>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy storeSingleFloatAtPointer: calloutState currentArg from: value.
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushStructure: pointer ofSize: structSize typeSpec: argSpec ofLength: argSpecSize in: calloutState [
	<var: #pointer type: #'void *'>
	<var: #argSpec type: #'sqInt *'>
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	| roundedSize |
	roundedSize := structSize + 3 bitClear: 3.
	calloutState currentArg + roundedSize > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	self memcpy: calloutState currentArg _: pointer _: structSize.
	calloutState currentArg: calloutState currentArg + roundedSize.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushUnsignedByte: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'unsigned char').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushUnsignedChar: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'unsigned char').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushUnsignedInt: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: value.
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushUnsignedLongLong: value in: calloutState [
	<var: #value type: #usqLong>
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 8 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy
		longAt: calloutState currentArg put: (self cCoerceSimple: value to: #usqInt);
		longAt: calloutState currentArg + 4 put: (self cCoerceSimple: value >> 32 to: #usqInt).
	calloutState currentArg: calloutState currentArg + 8.
	^0
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> ffiPushUnsignedShort: value in: calloutState [
	<var: #calloutState type: #'CalloutState *'>
	<inline: true>
	calloutState currentArg + 4 > calloutState limit ifTrue:
		[^FFIErrorCallFrameTooBig].
	interpreterProxy longAt: calloutState currentArg put: (self cCoerceSimple: value to: #'unsigned short').
	calloutState currentArg: calloutState currentArg + 4.
	^0
]

{ #category : #'callout support' }
ThreadedIA32FFIPlugin >> ffiReturnStruct: longLongRet ofType: ffiRetType in: calloutState [
	<var: #longLongRet type: #usqLong>
	<var: #calloutState type: #'CalloutState *'>
	"Create a structure return value from an external function call.  The value as been stored in
	 alloca'ed space pointed to by the calloutState."
	| retOop retClass oop |
	<inline: true>
	retClass := interpreterProxy fetchPointer: 1 ofObject: ffiRetType.
	retOop := interpreterProxy instantiateClass: retClass indexableSize: 0.
	self remapOop: retOop
		in: [oop := interpreterProxy 
					instantiateClass: interpreterProxy classByteArray 
					indexableSize: calloutState structReturnSize].
	self memcpy: (interpreterProxy firstIndexableField: oop)
		_: ((self returnStructInRegisters: calloutState structReturnSize)
				ifTrue: [(self addressOf: longLongRet) asVoidPointer]
				ifFalse: [calloutState limit])
		 _: calloutState structReturnSize.
	interpreterProxy storePointer: 0 ofObject: retOop withValue: oop.
	^retOop
]

{ #category : #marshalling }
ThreadedIA32FFIPlugin >> returnStructInRegisters: returnStructSize [
	"Answer if a struct result of a given size is returned in memory or not."
	<cmacro: '(sz) (WIN32_X86_STRUCT_RETURN && (sz) <= 8 && !((sz)&((sz)-1)))'>
	^returnStructSize <= 8 and: [returnStructSize isPowerOfTwo]
]
