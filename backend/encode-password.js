const password = 'C0uAv:y:XIpOs@)!3f1#Q(^=J8)un!f7';
const encoded = encodeURIComponent(password);
console.log('Original:', password);
console.log('Encoded:', encoded);
console.log('Full URL:', `postgresql://threadart_user:${encoded}@localhost:5432/threadart_db?schema=public`);