Class {
	#name : #StackDepthFinder,
	#superclass : #InstructionStream,
	#instVars : [
		'stackp',
		'joins',
		'encoderClass',
		'deadCode'
	],
	#category : #'VMMaker-Support'
}

{ #category : #accessing }
StackDepthFinder >> allStackPointers [
	"Answer a Dictionary from method to Array of stack pointers for all methods ioncluded in the receiver's method."
	"(StackDepthFinder on: StackDepthFinder >> #allStackPointers) allStackPointers"
	| allStackPointers method endPC |
	allStackPointers := Dictionary new.
	allStackPointers at: (method := self method) put: self stackPointers.
	endPC := pc.
	method nestedBlockMethods do:
		[:blockMethod|
		self method: blockMethod pc: blockMethod initialPC.
		allStackPointers at: blockMethod put: self stackPointers].
	self method: method pc: endPC.
	^allStackPointers
]

{ #category : #'instruction decoding' }
StackDepthFinder >> blockReturnConstant: value [
	"Return Constant From Block bytecode."
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> blockReturnTop [
	"Return Top Of Stack bytecode."
	self drop.
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> branchIfInstanceOf: behaviorOrArrayOfBehavior distance: delta [
	self drop.
	self doJump: delta
]

{ #category : #'instruction decoding' }
StackDepthFinder >> branchIfNotInstanceOf: behaviorOrArrayOfBehavior distance: delta [ 
	self drop.
	self doJump: delta
]

{ #category : #'instruction decoding' }
StackDepthFinder >> callInlinePrimitive: primitiveIndex [
	"The convention for inline primitives is that the argument count is primitiveIndex // 1000 - 1,
	 so receiverless 0-arg prims are from 0 to 999 (does this even make sense?), 0-arg prims
	 are from 1 to 1999, 2-arg prims from 1000 to 1999, and so on.
	 Primitives over 6000 are jumps."
	primitiveIndex >= 6000 ifTrue: [
		| upperByte delta |
		 self drop: (primitiveIndex - 4999) // 1000.
		 upperByte := self method at: pc - 6.
		 upperByte > 127 ifTrue: [upperByte := upperByte - 256].
		 delta := upperByte << 8 + (self method at: pc - 4).
		 delta < 0
			ifTrue:
				[(joins at: pc + delta) ~= stackp ifTrue: [(Notification new tag: #'bad join'; signal)]]
			ifFalse:
				[joins at: pc + delta put: stackp].
		^ self ].
	self drop: (primitiveIndex // 1000 - 1 max: 0)
]

{ #category : #'instruction decoding' }
StackDepthFinder >> callMappedInlinePrimitive: primIndex [
	self drop: (primIndex // 50 - 1 max: 0)
]

{ #category : #'instruction decoding' }
StackDepthFinder >> callPrimitive: primitiveIndex [
	"Call Primitive bytecode."
	"Phhh.... stackDeltaForPrimitive:in: is in BytecodeSets.  But since the default response
	 to callPrimitive: is nothing, just handle this with an MNU for now."
	[self drop: (encoderClass stackDeltaForPrimitive: primitiveIndex in: self method) negated]
		on: MessageNotUnderstood
		do: [:ex|
			ex message selector ~~ #stackDeltaForPrimitive:in: ifTrue:
				[ex pass]]
]

{ #category : #accessing }
StackDepthFinder >> containsMismatchedJoin [
	| end |
	end := self method endPC.
	[[self pc <= end]
		whileTrue:
			[((joins at: pc) notNil and: [stackp ~= (joins at: pc)]) ifTrue: [^true].
			 self interpretNextInstructionFor: self]]
		on: Notification
		do: [:ex|
			ex tag == #'bad join' ifTrue: [^true].
			ex pass].
	^false

	"StackDepthFinder methodDict values collect: [:m| (StackDepthFinder on: m) stackPointers]"
	"StackDepthFinder methodDict values select: [:m| (StackDepthFinder on: m) containsMismatchedJoin]"

	"| jumpers |
	 jumpers := CompiledMethod allInstances select:
						[:cm| | is |
						is := InstructionStream on: cm.
						is scanFor: [:ign| is willJump]].
	(jumpers select: [:cm| (StackDepthFinder on: cm) containsMismatchedJoin])
			asSortedCollection: [:cm1 :cm2| cm1 endPC <= cm2 endPC]"

	"| jumpers |
	 jumpers := CompiledMethod allInstances select:
						[:cm| | is |
						is := InstructionStream on: cm.
						is scanFor: [:ign| is willJump]].
	(jumpers reject: [:cm| (StackDepthFinder on: cm) containsMismatchedJoin])
			asSortedCollection: [:cm1 :cm2| cm1 endPC <= cm2 endPC]"

	"| jumpers result |
	 jumpers := CompiledMethod allInstances select:
						[:cm| | is |
						is := InstructionStream on: cm.
						is scanFor: [:ign| is willJump]].
	result := (jumpers select: [:cm| (StackDepthFinder on: cm) containsMismatchedJoin])
				asSortedCollection: [:cm1 :cm2| cm1 endPC <= cm2 endPC].
	 SystemNavigation new browseMessageList: (result collect: [:ea| ea methodReference]) name: 'mismatched joins'.
	 result"
]

{ #category : #'instruction decoding' }
StackDepthFinder >> directedSuperSend: selector numArgs: numArgs [
	self drop: numArgs + 1
]

{ #category : #'instruction decoding' }
StackDepthFinder >> doDup [
	"Duplicate Top Of Stack bytecode."
	self push
]

{ #category : #'stack depth' }
StackDepthFinder >> doJump: delta [
	deadCode ifTrue:
		[^self].
	delta < 0
		ifTrue:
			[(joins at: pc + delta) ~= stackp ifTrue: [(Notification new tag: #'bad join'; signal)]]
		ifFalse:
			[joins at: pc + delta put: stackp]
]

{ #category : #'instruction decoding' }
StackDepthFinder >> doNop [
	"do nothing ;-)"
]

{ #category : #'instruction decoding' }
StackDepthFinder >> doPop [
	"Remove Top Of Stack bytecode."
	deadCode ifFalse:
		[self drop]
]

{ #category : #'stack depth' }
StackDepthFinder >> drop [
	stackp := stackp - 1
]

{ #category : #'stack depth' }
StackDepthFinder >> drop: n [
	stackp := stackp - n
]

{ #category : #accessing }
StackDepthFinder >> encoderClass [

	^encoderClass
]

{ #category : #accessing }
StackDepthFinder >> encoderClass: anObject [

	encoderClass := anObject
]

{ #category : #decoding }
StackDepthFinder >> interpretNextInstructionFor: client [
	(deadCode and: [(joins at: pc) notNil]) ifTrue:
		[deadCode := false].
	joins at: pc put: stackp.
	^encoderClass
		ifNil: [super interpretNextInstructionFor: client]
		ifNotNil: [encoderClass interpretNextInstructionFor: client in: self]
]

{ #category : #accessing }
StackDepthFinder >> joins [
	^joins
]

{ #category : #'instruction decoding' }
StackDepthFinder >> jump: delta [
	"Unconditional Jump bytecode."
	self doJump: delta.
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> jump: delta if: condition [ 
	"Conditional Jump bytecode."
	self drop.
	self doJump: delta
]

{ #category : #private }
StackDepthFinder >> method: method pc: startpc [
	super method: method pc: startpc.
	"The + 1 is there for full blocks ending with non local return,
	as the following pc is mapped and beyong endPC"
	joins := Array new: method endPC + 1.
	stackp := method numTemps.
	deadCode := false
]

{ #category : #'instruction decoding' }
StackDepthFinder >> methodReturnConstant: value [ 
	"Return Constant bytecode."
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> methodReturnReceiver [
	"Return Self bytecode."
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> methodReturnTop [
	"Return Top Of Stack bytecode."
	self drop.
	self resetStackAfterBranchOrReturn
]

{ #category : #'instruction decoding' }
StackDepthFinder >> popIntoLiteralVariable: anAssociation [ 
	"Remove Top Of Stack And Store Into Literal Variable bytecode."
	self drop
]

{ #category : #'instruction decoding' }
StackDepthFinder >> popIntoReceiverVariable: offset [ 
	"Remove Top Of Stack And Store Into Instance Variable bytecode."
	self drop
]

{ #category : #'instruction decoding' }
StackDepthFinder >> popIntoRemoteTemp: remoteTempIndex inVectorAt: tempVectorIndex [
	"Remove Top Of Stack And Store Into Offset of Temp Vector bytecode."
	self drop
]

{ #category : #'instruction decoding' }
StackDepthFinder >> popIntoTemporaryVariable: offset [ 
	"Remove Top Of Stack And Store Into Temporary Variable bytecode."
	self drop
]

{ #category : #'stack depth' }
StackDepthFinder >> push [
	stackp := stackp + 1
]

{ #category : #'stack depth' }
StackDepthFinder >> push: n [
	stackp := stackp + n
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushActiveContext [
	"Push Active Context On Top Of Its Own Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushClosureCopyNumCopiedValues: numCopied numArgs: numArgs blockSize: blockSize [
	"Push Closure bytecode."
	numCopied = 0
		ifTrue: [self push]
		ifFalse: [numCopied > 1 ifTrue:
					[self drop: numCopied - 1]].
	self doJump: blockSize.
	stackp := numCopied + numArgs
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushConsArrayWithElements: numElements [
	"Push Cons Array of size numElements popping numElements items from the stack into the array bytecode."
	self drop: numElements - 1
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushConstant: value [
	"Push Constant, value, on Top Of Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushExplicitOuter: level [
	"Push receiver for explcit outer, on Top Of Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushFullClosure: literal numCopied: numCopied [
	"Push Closure bytecode."
	numCopied = 0
		ifTrue: [self push]
		ifFalse: [numCopied > 1 ifTrue:
					[self drop: numCopied - 1]]
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushFullClosure: literal numCopied: numCopied receiverOnStack: receiverOnStack ignoreOuterContext: ignoreOuterContext [
	"Push Closure bytecode."
	| delta |
	delta := 1 - (receiverOnStack ifTrue: [1] ifFalse: [0]) - numCopied.
	delta ~= 0 ifTrue: [self drop: delta negated]
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushLiteralVariable: anAssociation [
	"Push Contents Of anAssociation On Top Of Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushNewArrayOfSize: numElements [ 
	"Push New Array of size numElements bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushReceiver [
	"Push Active Context's Receiver on Top Of Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushReceiverVariable: offset [
	"Push Contents Of the Receiver's Instance Variable Whose Index 
	is the argument, offset, On Top Of Stack bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushRemoteTemp: remoteTempIndex inVectorAt: tempVectorIndex [
	"Push Contents at Offset in Temp Vector bytecode."
	self push
]

{ #category : #'instruction decoding' }
StackDepthFinder >> pushTemporaryVariable: offset [
	"Push Contents Of Temporary Variable Whose Index Is the 
	argument, offset, On Top Of Stack bytecode."
	self push
]

{ #category : #'stack depth' }
StackDepthFinder >> resetStackAfterBranchOrReturn [
	pc <= joins size ifTrue:
		[(joins at: pc) ifNil:
			["We would like to raise an error here, but we can't because the bytecode
			  compiler doesn't remove dead code.  e.g. the following doesn't reach ^nil
			  but is legal Smalltalk:
				self foo
					ifTrue: [^self bar]
					ifFalse: [^self baz].
				^nil"
				deadCode := true.
				^self].
		 stackp := joins at: pc]
]

{ #category : #'instruction decoding' }
StackDepthFinder >> send: selector super: supered numArgs: numArgs [
	"Send Message With Selector, selector, bytecode. The argument, 
	supered, indicates whether the receiver of the message is specified with 
	'super' in the source method. The arguments of the message are found in 
	the top numArguments locations on the stack and the receiver just 
	below them."
	self drop: numArgs
]

{ #category : #'instruction decoding' }
StackDepthFinder >> sendToAbsentDynamicSuperclass: selector numArgs: numArgs [
	"Dynamic Superclass Send Message With Selector, selector, to absent implicit receiver bytecode."
	self drop: numArgs - 1 "e.g. if no args pushes a result"
]

{ #category : #'instruction decoding' }
StackDepthFinder >> sendToAbsentImplicitReceiver: selector numArgs: numArgs [
	"Send Message With Selector, selector, to absent implicit receiver bytecode."
	self drop: numArgs - 1 "e.g. if no args pushes a result"
]

{ #category : #'instruction decoding' }
StackDepthFinder >> sendToAbsentOuter: selector numArgs: numArgs depth: depth [
	self drop: numArgs - 1 "e.g. if no args pushes a result"
]

{ #category : #'instruction decoding' }
StackDepthFinder >> sendToAbsentSelf: selector numArgs: numArgs [
	self drop: numArgs - 1 "e.g. if no args pushes a result"
]

{ #category : #accessing }
StackDepthFinder >> stackPointerAt: aPC [ 
	[pc < aPC] whileTrue:
		[self interpretNextInstructionFor: self].
	^pc = aPC ifTrue: [stackp]
]

{ #category : #accessing }
StackDepthFinder >> stackPointers [
	"Collect the stack depth for each bytecode in the method.
	 For the convenience of clients, write the stack depth for extended bytecodes
	 to the bytecode pc, as well as the bytecocdes' extensions' pcs."
	| method stackPointers end |
	"endPC +1 because of full blocks that can end with NLR effectively mapping the pc right after the end PC"
	stackPointers :=  Array new: (end := (method := self method) endPC) + 1.
	encoderClass ifNil: [encoderClass := method encoderClass].
	[pc <= end] whileTrue:
		[stackPointers at: pc put: stackp.
		 encoderClass extensionsAt: pc in: method into:
			[:extA :extB :delta|
			2 to: delta by: 2 do: [ :dlt |
				stackPointers at: pc + dlt put: stackp]].
		 self interpretNextInstructionFor: self].
	^stackPointers
]

{ #category : #accessing }
StackDepthFinder >> stackp [
	^stackp
]

{ #category : #'instruction decoding' }
StackDepthFinder >> storeIntoLiteralVariable: anAssociation [ 
	"Store Top Of Stack Into Literal Variable Of Method bytecode."

]

{ #category : #'instruction decoding' }
StackDepthFinder >> storeIntoReceiverVariable: offset [ 
	"Store Top Of Stack Into Instance Variable Of Method bytecode."

]

{ #category : #'instruction decoding' }
StackDepthFinder >> storeIntoRemoteTemp: remoteTempIndex inVectorAt: tempVectorIndex [
	"Store Top Of Stack And Store Into Offset of Temp Vector bytecode."
]

{ #category : #'instruction decoding' }
StackDepthFinder >> storeIntoTemporaryVariable: offset [ 
	"Store Top Of Stack Into Temporary Variable Of Method bytecode."

]

{ #category : #'instruction decoding' }
StackDepthFinder >> trap [
	
]

{ #category : #'instruction decoding' }
StackDepthFinder >> trapIfNotInstanceOf: behaviorOrArrayOfBehavior [
	"If the top of stack is not an instance of either the argument, or, if the argument is an Array,
	  any of the elements of the argument, send the class trap message to the current context."
	self drop
]
