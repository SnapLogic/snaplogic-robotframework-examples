module.exports = (req, res, next) => {
  // Add CORS headers
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  
  // Add timestamp to responses
  if (req.method !== 'OPTIONS') {
    res.locals.data = res.locals.data || {};
    res.locals.data.timestamp = new Date().toISOString();
  }
  
  // Simulate authentication
  if (req.path !== '/health' && req.path !== '/auth/login') {
    const authHeader = req.headers['authorization'];
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }
  
  // Continue to JSON Server router
  next();
}
